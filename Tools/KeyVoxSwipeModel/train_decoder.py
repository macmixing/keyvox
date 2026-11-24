"""Trains the decoder on a frozen encoder's outputs and writes it to `models/<run>/`.

The encoder run must already have `best.pt` and a tuned `scoring.json`. Each training
swipe whose word is in the lexicon is decoded once with the encoder; the highest-scoring
wrong candidates become that swipe's hard negatives. The loss is a listwise cross-entropy
that ranks the true word above its negatives, each scored exactly as at decode time
(`scoring.py`, with the encoder's tuned weights), plus 0.3 times the true word's CTC loss
per key. After every epoch the validation split is decoded with the decoder, and the
checkpoint with the best validation top-1 is kept as `decoder.pt`.

The encoder's outputs and the mined negatives are saved once as `decoder-inputs.npz` and
reused; `--prepare-only` stops there, so the encoder can run on one machine's GPU and the
decoder can train elsewhere."""

import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

from decode import Pruning, beam_search
from decoder_model import DecoderConfig, SwipeDecoder
from emissions import compute_frames, load_encoder
from evaluate import decode_accuracy, target_forms
from layouts import load_layout
from lexicon import build_trie, load_lexicon
from ranking import lexicon_paths, ranking_loss, ranking_options
from run_emissions import DECODER_CHECKPOINT
from scoring import Scoring, candidate_scores

WEIGHT_DECAY = 1e-2
GRADIENT_CLIP = 1.0
WARMUP_FRACTION = 0.05
VALIDATION_BATCH = 4096
INPUTS_FILE = "decoder-inputs.npz"


def prepare_inputs(arguments, encoder_dir, encoder_settings, scoring, pruning, layout, lexicon, trie, device,
                   path: Path) -> None:
    """Runs the frozen encoder over the training and validation swipes, mines each
    training swipe's hard negatives, and saves what training needs."""
    encoder = load_encoder(encoder_dir / "best.pt", device)
    prepared = arguments.data_dir / "prepared"
    names = ["train.npz"] + (["extra.npz"] if encoder_settings["extra"] else [])
    xy = np.concatenate([np.load(prepared / name)["xy"] for name in names])
    forms = np.concatenate([np.load(prepared / name)["form"] for name in names])
    if arguments.limit:
        xy, forms = xy[: arguments.limit], forms[: arguments.limit]
    targets = target_forms(forms, lexicon.forms)
    frames = compute_frames(encoder, xy, layout, device, dtype=np.float16)
    symbols = len(layout.letters) + 1
    candidates = beam_search(arguments.data_dir, frames[..., :symbols].astype(np.float32), trie, pruning)
    scores = candidate_scores(candidates, lexicon.frequency, trie.form_path_length, scoring)
    _, path_lengths = lexicon_paths(lexicon, layout.key_index, frames.shape[1])
    options, keep = ranking_options(candidates, scores, targets, path_lengths)
    val = np.load(prepared / "val.npz")
    np.savez(path, train_frames=frames[keep], train_options=options[keep],
             val_frames=compute_frames(encoder, val["xy"], layout, device, dtype=np.float16),
             val_targets=target_forms(val["form"], lexicon.forms))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("encoder_run")
    parser.add_argument("run")
    parser.add_argument("lexicon", type=Path)
    parser.add_argument("--epochs", type=int, default=20)
    parser.add_argument("--batch", type=int, default=1024)
    parser.add_argument("--learning-rate", type=float, default=1e-3)
    parser.add_argument("--limit", type=int, default=0, help="train on only the first N swipes")
    parser.add_argument("--device", default="mps" if torch.backends.mps.is_available() else "cpu")
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--prepare-only", action="store_true",
                        help=f"only write models/<run>/{INPUTS_FILE}, so training can run on another machine")
    arguments = parser.parse_args()

    torch.manual_seed(arguments.seed)
    device = torch.device(arguments.device)
    models = arguments.data_dir / "models"
    encoder_dir, run_dir = models / arguments.encoder_run, models / arguments.run
    run_dir.mkdir(parents=True, exist_ok=True)
    encoder_settings = json.loads((encoder_dir / "settings.json").read_text())
    scoring = Scoring.load(encoder_dir / "scoring.json")
    pruning = Pruning()
    layout = load_layout(arguments.data_dir, encoder_settings["layout"])
    lexicon = load_lexicon(arguments.lexicon)
    trie = build_trie(lexicon, layout)
    inputs_path = run_dir / INPUTS_FILE
    if not inputs_path.exists():
        prepare_inputs(arguments, encoder_dir, encoder_settings, scoring, pruning, layout, lexicon, trie, device,
                       inputs_path)
    if arguments.prepare_only:
        return
    inputs = np.load(inputs_path)
    print(f"decoder training swipes: {len(inputs['train_options'])}", flush=True)
    train_frames = torch.from_numpy(inputs["train_frames"]).to(device)
    train_options = torch.from_numpy(inputs["train_options"]).to(device)
    val_frames = inputs["val_frames"].astype(np.float32)
    val_targets = inputs["val_targets"]
    paths, path_lengths = lexicon_paths(lexicon, layout.key_index, val_frames.shape[1])
    paths_t, lengths_t = torch.from_numpy(paths), torch.from_numpy(path_lengths)
    frequency = torch.from_numpy(lexicon.frequency).to(device)
    symbols = len(layout.letters) + 1

    config = DecoderConfig(symbols=symbols, coefficients=val_frames.shape[2] - symbols - 1)
    decoder = SwipeDecoder(config).to(device)
    optimizer = torch.optim.AdamW(decoder.parameters(), lr=arguments.learning_rate, weight_decay=WEIGHT_DECAY)
    steps_per_epoch = len(train_frames) // arguments.batch
    total = steps_per_epoch * arguments.epochs
    warmup = max(1, int(total * WARMUP_FRACTION))
    settings = {**vars(arguments), "data_dir": str(arguments.data_dir), "lexicon": str(arguments.lexicon),
                "config": config.to_dict(), "scoring": scoring.__dict__,
                "parameters": sum(p.numel() for p in decoder.parameters())}
    (run_dir / "settings.json").write_text(json.dumps(settings, indent=2) + "\n")
    print(f"{settings['parameters']} parameters", flush=True)

    best = -1.0
    for epoch in range(arguments.epochs):
        decoder.train()
        started = time.time()
        order = torch.randperm(len(train_frames), device=device)
        total_loss = 0.0
        for batch_number in range(steps_per_epoch):
            step = epoch * steps_per_epoch + batch_number
            rate = (step + 1) / warmup if step < warmup else 0.5 * (1 + math.cos(math.pi * (step - warmup) / max(1, total - warmup)))
            for group in optimizer.param_groups:
                group["lr"] = arguments.learning_rate * rate
            index = order[batch_number * arguments.batch:(batch_number + 1) * arguments.batch]
            emissions = decoder(train_frames[index].float())
            loss = ranking_loss(emissions, train_options[index], paths_t, lengths_t, frequency, scoring)
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(decoder.parameters(), GRADIENT_CLIP)
            optimizer.step()
            total_loss += loss.item()

        decoder.eval()
        with torch.no_grad():
            val_emissions = np.concatenate([
                decoder(torch.from_numpy(val_frames[start:start + VALIDATION_BATCH]).to(device)).cpu().numpy()
                for start in range(0, len(val_frames), VALIDATION_BATCH)
            ])
        _, _, accuracy = decode_accuracy(arguments.data_dir, val_emissions, trie, lexicon, scoring, val_targets, pruning)
        record = {"epoch": epoch, "loss": total_loss / steps_per_epoch,
                  **{f"val_{name}": value for name, value in accuracy.items()}, "seconds": time.time() - started}
        with open(run_dir / "log.jsonl", "a") as log:
            log.write(json.dumps(record) + "\n")
        print(json.dumps(record), flush=True)
        if accuracy["top1"] > best:
            best = accuracy["top1"]
            torch.save({"model": decoder.state_dict(), "config": config.to_dict(),
                        "encoder_run": arguments.encoder_run}, run_dir / DECODER_CHECKPOINT)


if __name__ == "__main__":
    main()
