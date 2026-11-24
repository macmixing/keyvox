"""Trains the decoder on a frozen encoder's outputs and writes it to `models/<run>/`.

The encoder run must already have `best.pt` and a tuned `scoring.json`. Each training
swipe whose word is in the lexicon is decoded once with the encoder; the highest-scoring
wrong candidates become that swipe's hard negatives. The loss is a listwise cross-entropy
that ranks the true word above its negatives, each scored exactly as at decode time
(`scoring.py`, with the encoder's tuned weights), plus 0.3 times the true word's CTC loss
per key. After every epoch the validation split is decoded with the decoder, and the
checkpoint with the best validation top-1 is kept as `decoder.pt`."""

import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch
from torch.nn import functional as F

from decode import Pruning, beam_search
from decoder_model import DecoderConfig, SwipeDecoder
from emissions import compute_frames, load_encoder
from evaluate import target_forms
from layouts import load_layout
from lexicon import Lexicon, build_trie, load_lexicon
from run_emissions import DECODER_CHECKPOINT
from scoring import Scoring, candidate_scores, target_ranks, top_k_accuracy
from words import key_path

NEGATIVES = 16
CTC_WEIGHT = 0.3
WEIGHT_DECAY = 1e-2
GRADIENT_CLIP = 1.0
WARMUP_FRACTION = 0.05
VALIDATION_BATCH = 4096


def lexicon_paths(lexicon: Lexicon, key_index: dict[str, int], frames: int) -> tuple[np.ndarray, np.ndarray]:
    """Every form's key path as CTC labels (key + 1), zero padded, and its length (0 when
    the form cannot be decoded in `frames` frames)."""
    paths = np.zeros((len(lexicon.forms), frames), dtype=np.int64)
    lengths = np.zeros(len(lexicon.forms), dtype=np.int64)
    for number, form in enumerate(lexicon.forms):
        path = key_path(form, key_index)
        if path and len(path) <= frames:
            paths[number, : len(path)] = np.array(path) + 1
            lengths[number] = len(path)
    return paths, lengths


def hard_negatives(candidates, scores: np.ndarray, targets: np.ndarray, count: int) -> np.ndarray:
    """[N, count] the best-scoring candidate forms that are not the target, -1 padded."""
    swipes = len(candidates.start) - 1
    group = np.repeat(np.arange(swipes), np.diff(candidates.start))
    order = np.lexsort((-scores, group))
    group, forms = group[order], candidates.form[order]
    wrong = forms != targets[group]
    group, forms = group[wrong], forms[wrong]
    first = np.searchsorted(group, np.arange(swipes))
    position = np.arange(len(group)) - first[group]
    keep = position < count
    negatives = np.full((swipes, count), -1, dtype=np.int32)
    negatives[group[keep], position[keep]] = forms[keep]
    return negatives


def word_scores(emissions, forms, paths, lengths, frequency, scoring: Scoring):
    """Decode-time scores of `forms` [B, M] (-1 for none) under emissions [B, T, S]."""
    batch, options = forms.shape
    valid = forms >= 0
    safe = forms.clamp(min=0)
    on_cpu = safe.cpu()
    labels = paths[on_cpu].reshape(batch * options, -1)
    label_lengths = lengths[on_cpu].reshape(-1).clamp(min=1)
    repeated = emissions.unsqueeze(1).expand(-1, options, -1, -1).reshape(batch * options, *emissions.shape[1:])
    frame_count = torch.full((batch * options,), emissions.shape[1], dtype=torch.long)
    nll = F.ctc_loss(repeated.transpose(0, 1).cpu(), labels, frame_count, label_lengths,
                     blank=0, reduction="none").to(emissions.device).reshape(batch, options)
    length = label_lengths.reshape(batch, options).to(emissions.device).float()
    score = -nll / length.pow(scoring.gamma) + scoring.frequency_weight * frequency[safe] + scoring.length_bonus * length
    return score.masked_fill(~valid, -math.inf), nll, length


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
    negatives = hard_negatives(candidates, scores, targets, NEGATIVES)
    paths, path_lengths = lexicon_paths(lexicon, layout.key_index, frames.shape[1])
    keep = (targets >= 0) & (path_lengths[np.maximum(targets, 0)] > 0)
    print(f"decoder training swipes: {keep.sum()} of {len(keep)}", flush=True)

    train_frames = torch.from_numpy(frames[keep]).to(device)
    train_options = torch.from_numpy(np.concatenate([targets[keep, None], negatives[keep]], axis=1).astype(np.int64)).to(device)
    del frames, candidates, scores
    val = np.load(prepared / "val.npz")
    val_frames = compute_frames(encoder, val["xy"], layout, device)
    val_targets = target_forms(val["form"], lexicon.forms)
    paths_t, lengths_t = torch.from_numpy(paths), torch.from_numpy(path_lengths)
    frequency = torch.from_numpy(lexicon.frequency).to(device)

    config = DecoderConfig(symbols=symbols, coefficients=encoder.config.basis ** 2)
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
        totals = torch.zeros(2)
        for batch_number in range(steps_per_epoch):
            step = epoch * steps_per_epoch + batch_number
            rate = (step + 1) / warmup if step < warmup else 0.5 * (1 + math.cos(math.pi * (step - warmup) / max(1, total - warmup)))
            for group in optimizer.param_groups:
                group["lr"] = arguments.learning_rate * rate
            index = order[batch_number * arguments.batch:(batch_number + 1) * arguments.batch]
            emissions = decoder(train_frames[index].float())
            score, nll, length = word_scores(emissions, train_options[index], paths_t, lengths_t, frequency, scoring)
            rank = F.cross_entropy(score, torch.zeros(len(index), dtype=torch.long, device=device))
            ctc = (nll[:, 0] / length[:, 0]).mean()
            optimizer.zero_grad(set_to_none=True)
            (rank + CTC_WEIGHT * ctc).backward()
            torch.nn.utils.clip_grad_norm_(decoder.parameters(), GRADIENT_CLIP)
            optimizer.step()
            totals += torch.tensor([rank.item(), ctc.item()])

        decoder.eval()
        with torch.no_grad():
            val_emissions = np.concatenate([
                decoder(torch.from_numpy(val_frames[start:start + VALIDATION_BATCH]).to(device)).cpu().numpy()
                for start in range(0, len(val_frames), VALIDATION_BATCH)
            ])
        val_candidates = beam_search(arguments.data_dir, val_emissions, trie, pruning)
        accuracy = top_k_accuracy(target_ranks(
            val_candidates, candidate_scores(val_candidates, lexicon.frequency, trie.form_path_length, scoring), val_targets))
        record = {"epoch": epoch, "rank": totals[0].item() / steps_per_epoch, "ctc": totals[1].item() / steps_per_epoch,
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
