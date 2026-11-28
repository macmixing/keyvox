"""Fine-tunes an encoder run with the listwise ranking objective (`ranking.py`) on swipes of several
keyboard layouts, each decoded and scored on its own layout's keys, and writes a new encoder run to
`models/<run>/`: `finetune_encoder.py`'s fine-tune, layout by layout.

The swipes are prepared arrays with a `layout` per swipe (`layout_swipes.py`), such as English
swipes moved onto the keyboard's letter layouts (`warp_layout_swipes.py`); their words are looked up
in `lexicon`, a unigram list as `evaluate.py` reads it. The base run needs a tuned `scoring.json`.
Each swipe's hard negatives are mined once with the base encoder on its own layout's key-path trie
of the lexicon; every batch holds swipes of one layout and is scored with that layout's key paths.
The validation swipes are decoded before training and after every epoch, layout by layout; each
epoch's weights are kept as `epoch-<n>.pt`, and `best.pt` holds the epoch with the best validation
top-1 over all layouts.

    python rank_layouts.py <data-dir> r3-ft2 k1 <unigrams.tsv> --swipes layouts-train --validation layouts-val"""

import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

from augment import AugmentConfig, augment_geometry
from decode import Pruning, beam_search
from emissions import compute_frames, load_encoder
from evaluate import decode_accuracy, target_forms
from layout_swipes import LayoutSwipes, layout_names, resolve_layout
from lexicon import build_trie, load_lexicon
from model import key_basis, log_emissions
from prepare_swipes import POINTS
from ranking import NEGATIVES, lexicon_paths, ranking_loss, ranking_options
from scoring import Scoring, candidate_scores, top_k_accuracy
from train import GRADIENT_CLIP, WARMUP_FRACTION, WEIGHT_DECAY, output_frames


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("base_run")
    parser.add_argument("run")
    parser.add_argument("lexicon", type=Path)
    parser.add_argument("--swipes", nargs="+", required=True, help="prepared names, each optionally :<times>")
    parser.add_argument("--validation", nargs="+", required=True, help="prepared names to choose the best epoch on")
    parser.add_argument("--epochs", type=int, default=3)
    parser.add_argument("--batch", type=int, default=1024)
    parser.add_argument("--learning-rate", type=float, default=5e-5)
    parser.add_argument("--negatives", type=int, default=NEGATIVES)
    parser.add_argument("--augment-probability", type=float, default=0.5)
    parser.add_argument("--seed", type=int, default=0)
    parser.add_argument("--device", default="mps" if torch.backends.mps.is_available() else "cpu")
    arguments = parser.parse_args()

    torch.manual_seed(arguments.seed)
    device = torch.device(arguments.device)
    models = arguments.data_dir / "models"
    base_dir, run_dir = models / arguments.base_run, models / arguments.run
    run_dir.mkdir(parents=True, exist_ok=True)
    base_settings = json.loads((base_dir / "settings.json").read_text())
    scoring = Scoring.load(base_dir / "scoring.json")
    pruning = Pruning()
    lexicon = load_lexicon(arguments.lexicon)
    frequency = torch.from_numpy(lexicon.frequency).to(device)

    layouts = {name: resolve_layout(arguments.data_dir, name)
               for name in sorted(layout_names(arguments.data_dir, arguments.swipes + arguments.validation))}
    numbers: dict[str, int] = {}
    train = LayoutSwipes(arguments.data_dir, arguments.swipes, layouts, numbers, device)
    val = LayoutSwipes(arguments.data_dir, arguments.validation, layouts, numbers, device)
    by_number = {number: layouts[name] for name, number in numbers.items()}
    tries = {number: build_trie(lexicon, layout) for number, layout in by_number.items()}
    paths, path_lengths = {}, {}
    for number, layout in by_number.items():
        found, lengths = lexicon_paths(lexicon, layout.key_index, output_frames(POINTS))
        paths[number], path_lengths[number] = torch.from_numpy(found), lengths
    centers = {number: torch.from_numpy(layout.centers).to(device) for number, layout in by_number.items()}
    print(f"train {len(train.lengths)} swipes, validation {len(val.lengths)}, layouts {sorted(numbers)}", flush=True)

    model = load_encoder(base_dir / "best.pt", device)
    model.eval()
    train_layouts = train.layouts.cpu().numpy()
    train_targets = target_forms(train.forms, lexicon.forms)
    options = np.full((len(train_targets), 1 + arguments.negatives), -1, dtype=np.int64)
    keep = np.zeros(len(train_targets), dtype=bool)
    for number, layout in by_number.items():
        rows = np.flatnonzero(train_layouts == number)
        if len(rows) == 0:
            continue
        emissions = compute_frames(model, train.xy[torch.from_numpy(rows).to(device)].cpu().numpy(), layout,
                                   device)[..., :len(layout.letters) + 1]
        candidates = beam_search(arguments.data_dir, emissions, tries[number], pruning)
        scores = candidate_scores(candidates, lexicon.frequency, tries[number].form_path_length, scoring)
        options[rows], keep[rows] = ranking_options(candidates, scores, train_targets[rows], path_lengths[number],
                                                    arguments.negatives)
        print(f"mined {layout.name}: {keep[rows].sum()} of {len(rows)} swipes", flush=True)
    trainable = torch.from_numpy(np.flatnonzero(keep))
    train_options = torch.from_numpy(options).to(device)

    val_layouts = val.layouts.cpu().numpy()
    val_targets = target_forms(val.forms, lexicon.forms)

    def validation_top1() -> dict:
        model.eval()
        ranks = np.full(len(val_targets), np.inf)
        for number, layout in by_number.items():
            rows = np.flatnonzero(val_layouts == number)
            if len(rows) == 0:
                continue
            emissions = compute_frames(model, val.xy[torch.from_numpy(rows).to(device)].cpu().numpy(), layout,
                                       device)[..., :len(layout.letters) + 1]
            _, ranks[rows], _ = decode_accuracy(arguments.data_dir, emissions, tries[number], lexicon, scoring,
                                                val_targets[rows], pruning)
        return top_k_accuracy(ranks)

    augment_config = AugmentConfig(probability=arguments.augment_probability, reverse_probability=0.0)
    optimizer = torch.optim.AdamW(model.parameters(), lr=arguments.learning_rate, weight_decay=WEIGHT_DECAY)
    steps_per_epoch = len(train.batches(arguments.batch, torch.Generator().manual_seed(0), trainable))
    total = steps_per_epoch * arguments.epochs
    warmup = max(1, int(total * WARMUP_FRACTION))
    settings = {**base_settings, "augment": augment_config.__dict__,
                "rank_layouts": {**vars(arguments), "data_dir": str(arguments.data_dir), "lexicon": str(arguments.lexicon),
                                 "scoring": scoring.__dict__, "layouts": sorted(numbers)}}
    (run_dir / "settings.json").write_text(json.dumps(settings, indent=2) + "\n")
    (run_dir / "scoring.json").write_text((base_dir / "scoring.json").read_text())

    def state() -> dict:
        return {"model": model.state_dict(), "config": model.config.to_dict(), "layout": "several"}

    accuracy = validation_top1()
    print(json.dumps({"epoch": -1, **{f"val_{k}": v for k, v in accuracy.items()}}), flush=True)
    best = accuracy["top1"]
    torch.save(state(), run_dir / "best.pt")
    for epoch in range(arguments.epochs):
        model.train()
        started = time.time()
        total_loss = 0.0
        epoch_batches = train.batches(arguments.batch, torch.Generator().manual_seed(arguments.seed * 7919 + epoch),
                                      trainable)
        for batch_number, index in enumerate(epoch_batches):
            step = epoch * steps_per_epoch + batch_number
            rate = (step + 1) / warmup if step < warmup else 0.5 * (1 + math.cos(math.pi * (step - warmup) / max(1, total - warmup)))
            for group in optimizer.param_groups:
                group["lr"] = arguments.learning_rate * rate
            number = int(train.layouts[index[0]])
            keys = centers[number].expand(len(index), -1, -1)
            key_mask = torch.ones(keys.shape[:2], dtype=torch.bool, device=device)
            swipes, keys = augment_geometry(train.xy[index], keys, key_mask, augment_config)
            coefficients, gate = model(swipes)
            emissions = log_emissions(coefficients, gate, key_basis(keys, model.config.basis), key_mask)
            loss = ranking_loss(emissions, train_options[index], paths[number], torch.from_numpy(path_lengths[number]),
                                frequency, scoring)
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            norm = torch.nn.utils.clip_grad_norm_(model.parameters(), GRADIENT_CLIP)
            if not torch.isfinite(norm + loss):
                raise RuntimeError(f"epoch {epoch} step {batch_number}: the loss or its gradient is not finite")
            optimizer.step()
            total_loss += loss.item()
        accuracy = validation_top1()
        record = {"epoch": epoch, "loss": total_loss / len(epoch_batches),
                  **{f"val_{k}": v for k, v in accuracy.items()}, "seconds": time.time() - started}
        with open(run_dir / "log.jsonl", "a") as log:
            log.write(json.dumps(record) + "\n")
        print(json.dumps(record), flush=True)
        torch.save(state(), run_dir / f"epoch-{epoch}.pt")
        if accuracy["top1"] > best:
            best = accuracy["top1"]
            torch.save(state(), run_dir / "best.pt")


if __name__ == "__main__":
    main()
