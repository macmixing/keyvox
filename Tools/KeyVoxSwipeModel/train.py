"""Trains the swipe encoder with CTC on prepared swipes and writes checkpoints to
`models/<run>/`.

The loss is CTC plus a one-sided penalty when the gates emit fewer keys than the word has:
0.05 * max(0, keys - sum of gate probabilities)^2. Each epoch logs the training loss and the
validation loss on unaugmented validation swipes to `models/<run>/log.jsonl`, and saves
`checkpoint.pt` (latest) and `best.pt` (lowest validation loss).

`checkpoint.pt` is also written every `--checkpoint-every` steps within an epoch. Every
step reseeds all random number generators from the seed, epoch, and step, and each epoch's
order comes from its own seeded generator, so `--resume` continues from the last
checkpoint with the same batches, augmentation, and dropout as an uninterrupted run."""

import argparse
import json
import math
import os
import time
from pathlib import Path

import numpy as np
import torch
from torch.nn import functional as F

from augment import AugmentConfig, augment_geometry, reverse_choice, reverse_swipes
from layouts import load_layout
from model import EncoderConfig, SwipeEncoder, key_basis, log_emissions
from prepare_swipes import POINTS
from run_settings import KEEP_DOUBLES
from swipe_data import load_swipes, trainable

EMISSION_PENALTY = 0.05
WARMUP_FRACTION = 0.05
FINAL_LEARNING_RATE = 2e-5
WEIGHT_DECAY = 1e-4
GRADIENT_CLIP = 1.0
VALIDATION_BATCH = 4096
_SEED_STRIDE = 1_000_003


def epoch_order(count: int, seed: int, epoch: int) -> torch.Tensor:
    """The epoch's shuffled order, a function of the seed and epoch only."""
    return torch.randperm(count, generator=torch.Generator().manual_seed(seed * _SEED_STRIDE + epoch))


def seed_step(seed: int, epoch: int, step: int) -> None:
    """Seeds every generator (CPU and GPU) for one step, so augmentation and dropout
    depend only on the seed, epoch, and step."""
    torch.manual_seed(((seed * _SEED_STRIDE + epoch) * _SEED_STRIDE + step) % (1 << 63))


def save_atomically(value: dict, path: Path) -> None:
    partial = path.with_suffix(path.suffix + ".part")
    torch.save(value, partial)
    os.replace(partial, path)


def output_frames(points: int) -> int:
    return points // 2


def loss_terms(model, xy, keys, key_mask, targets, lengths, basis_size):
    coefficients, gate = model(xy)
    emissions = log_emissions(coefficients, gate, key_basis(keys, basis_size), key_mask)
    frames = torch.full((xy.shape[0],), emissions.shape[1], dtype=torch.long, device=xy.device)
    ctc = F.ctc_loss(emissions.transpose(0, 1), targets, frames, lengths, blank=0, zero_infinity=True)
    shortfall = F.relu(lengths.to(gate.dtype) - torch.sigmoid(gate).sum(dim=1))
    return ctc, EMISSION_PENALTY * shortfall.square().mean()


def learning_rate(step: int, total: int, peak: float) -> float:
    warmup = max(1, int(total * WARMUP_FRACTION))
    if step < warmup:
        return peak * (step + 1) / warmup
    progress = (step - warmup) / max(1, total - warmup)
    return FINAL_LEARNING_RATE + (peak - FINAL_LEARNING_RATE) * 0.5 * (1 + math.cos(math.pi * progress))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("run")
    parser.add_argument("--layout", default="qwerty")
    parser.add_argument("--extra", action="store_true", help="also train on prepared/extra.npz")
    parser.add_argument("--epochs", type=int, default=120)
    parser.add_argument("--batch", type=int, default=1024)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--augment-probability", type=float, default=1.0)
    parser.add_argument("--width", type=int, default=EncoderConfig.width)
    parser.add_argument("--head-width", type=int, default=EncoderConfig.head_width)
    parser.add_argument("--expansion", type=int, default=EncoderConfig.expansion)
    parser.add_argument("--dilations", default=",".join(map(str, EncoderConfig.dilations)))
    parser.add_argument("--dropout", type=float, default=EncoderConfig.dropout)
    parser.add_argument("--keep-doubles", action="store_true", help="keep repeated keys in CTC targets")
    parser.add_argument("--resume", action="store_true")
    parser.add_argument("--checkpoint-every", type=int, default=200, help="steps between mid-epoch checkpoints")
    parser.add_argument("--limit", type=int, default=0, help="train on only the first N trainable swipes")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--device", default="mps" if torch.backends.mps.is_available() else "cpu")
    arguments = parser.parse_args()

    torch.manual_seed(arguments.seed)
    device = torch.device(arguments.device)
    run_dir = arguments.data_dir / "models" / arguments.run
    run_dir.mkdir(parents=True, exist_ok=True)

    config = EncoderConfig(
        width=arguments.width,
        expansion=arguments.expansion,
        dilations=tuple(int(value) for value in arguments.dilations.split(",")),
        head_width=arguments.head_width,
        dropout=arguments.dropout,
    )
    augment_config = AugmentConfig(probability=arguments.augment_probability)
    layout = load_layout(arguments.data_dir, arguments.layout)
    frames = output_frames(POINTS)
    prepared = arguments.data_dir / "prepared"
    train_paths = [prepared / "train.npz"] + ([prepared / "extra.npz"] if arguments.extra else [])
    train = trainable(load_swipes(train_paths, layout, frames, arguments.keep_doubles))
    if arguments.limit:
        train = type(train)(xy=train.xy[: arguments.limit], forms=train.forms[: arguments.limit],
                            targets=train.targets[: arguments.limit], lengths=train.lengths[: arguments.limit])
    val = trainable(load_swipes([prepared / "val.npz"], layout, frames, arguments.keep_doubles))
    print(f"train {len(train.lengths)} swipes, val {len(val.lengths)} swipes", flush=True)

    def to_device(swipes):
        return (
            torch.from_numpy(swipes.xy).to(device),
            torch.from_numpy(swipes.targets).to(device),
            torch.from_numpy(swipes.lengths).to(device),
        )

    train_xy, train_targets, train_lengths = to_device(train)
    val_xy, val_targets, val_lengths = to_device(val)
    centers = torch.from_numpy(layout.centers).to(device)

    model = SwipeEncoder(config).to(device)
    optimizer = torch.optim.AdamW(model.parameters(), lr=arguments.learning_rate, weight_decay=WEIGHT_DECAY)
    steps_per_epoch = len(train.lengths) // arguments.batch
    total_steps = steps_per_epoch * arguments.epochs
    # A checkpoint's "epoch" is the last completed epoch; "step" counts the steps already
    # taken in the epoch after it.
    start_epoch, start_step, best = 0, 0, math.inf
    resumed_totals = None
    checkpoint_path = run_dir / "checkpoint.pt"
    if arguments.resume and checkpoint_path.exists():
        # Loaded on the CPU: the model and optimizer move their tensors to the GPU themselves,
        # and the optimizer's step counts stay on the CPU, as in a run that never stopped
        # (on the GPU, every optimizer step would wait on the GPU once per parameter).
        state = torch.load(checkpoint_path, map_location="cpu")
        model.load_state_dict(state["model"])
        optimizer.load_state_dict(state["optimizer"])
        start_epoch, start_step, best = state["epoch"] + 1, state.get("step", 0), state["best"]
        resumed_totals = state.get("totals")
        print(f"resuming at epoch {start_epoch}, step {start_step}", flush=True)
    settings = {**vars(arguments), "data_dir": str(arguments.data_dir), "config": config.to_dict(),
                "augment": augment_config.__dict__, KEEP_DOUBLES: arguments.keep_doubles, "parameters": sum(p.numel() for p in model.parameters())}
    (run_dir / "settings.json").write_text(json.dumps(settings, indent=2) + "\n")
    print(f"{settings['parameters']} parameters", flush=True)

    for epoch in range(start_epoch, arguments.epochs):
        model.train()
        started = time.time()
        order = epoch_order(len(train.lengths), arguments.seed, epoch).to(device)
        first_step = start_step if epoch == start_epoch else 0
        totals = torch.zeros(2, device=device)
        if first_step and resumed_totals is not None:
            totals = resumed_totals.to(device)
        for batch_number in range(first_step, steps_per_epoch):
            step = epoch * steps_per_epoch + batch_number
            seed_step(arguments.seed, epoch, batch_number)
            for group in optimizer.param_groups:
                group["lr"] = learning_rate(step, total_steps, arguments.learning_rate)
            index = order[batch_number * arguments.batch:(batch_number + 1) * arguments.batch]
            xy, targets, lengths = train_xy[index], train_targets[index], train_lengths[index]
            batch = xy.shape[0]
            keys = centers.expand(batch, -1, -1)
            key_mask = torch.ones(batch, keys.shape[1], dtype=torch.bool, device=device)
            xy, keys = augment_geometry(xy, keys, key_mask, augment_config)
            xy, targets = reverse_swipes(xy, targets, lengths, reverse_choice(batch, augment_config, device))
            ctc, penalty = loss_terms(model, xy, keys, key_mask, targets, lengths, config.basis)
            optimizer.zero_grad(set_to_none=True)
            (ctc + penalty).backward()
            torch.nn.utils.clip_grad_norm_(model.parameters(), GRADIENT_CLIP)
            optimizer.step()
            totals += torch.stack([ctc.detach(), penalty.detach()])
            taken = batch_number + 1
            if arguments.checkpoint_every and taken % arguments.checkpoint_every == 0 and taken < steps_per_epoch:
                save_atomically({"model": model.state_dict(), "config": config.to_dict(), "layout": layout.name,
                                 "optimizer": optimizer.state_dict(), "epoch": epoch - 1, "step": taken,
                                 "best": best, "totals": totals.cpu()}, checkpoint_path)

        model.eval()
        val_total, val_count = 0.0, 0
        with torch.no_grad():
            for start in range(0, len(val.lengths), VALIDATION_BATCH):
                xy = val_xy[start:start + VALIDATION_BATCH]
                batch = xy.shape[0]
                keys = centers.expand(batch, -1, -1)
                key_mask = torch.ones(batch, keys.shape[1], dtype=torch.bool, device=device)
                ctc, _ = loss_terms(model, xy, keys, key_mask, val_targets[start:start + VALIDATION_BATCH],
                                    val_lengths[start:start + VALIDATION_BATCH], config.basis)
                val_total += ctc.item() * batch
                val_count += batch
        train_ctc, train_penalty = (totals / steps_per_epoch).tolist()
        val_ctc = val_total / val_count
        record = {"epoch": epoch, "train_ctc": train_ctc, "train_penalty": train_penalty, "val_ctc": val_ctc,
                  "learning_rate": optimizer.param_groups[0]["lr"], "seconds": time.time() - started,
                  **({"resumed_at_step": first_step} if first_step else {})}
        with open(run_dir / "log.jsonl", "a") as log:
            log.write(json.dumps(record) + "\n")
        print(json.dumps(record), flush=True)

        state = {"model": model.state_dict(), "config": config.to_dict(), "layout": layout.name}
        if val_ctc < best:
            best = val_ctc
            save_atomically(state, run_dir / "best.pt")
        save_atomically({**state, "optimizer": optimizer.state_dict(), "epoch": epoch, "step": 0, "best": best},
                        checkpoint_path)


if __name__ == "__main__":
    main()
