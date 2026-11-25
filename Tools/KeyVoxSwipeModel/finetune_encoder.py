"""Fine-tunes a CTC-trained encoder with the listwise ranking objective (`ranking.py`)
and writes the result as a new encoder run in `models/<run>/`.

The base run must have `best.pt` and a tuned `scoring.json`. Hard negatives are mined
once from the base encoder on unaugmented training swipes. Training keeps the base run's
joint swipe-and-keyboard augmentation (geometry only: a reversed swipe would need reversed
negatives). The validation split is decoded before training and after every epoch, and
the weights with the best validation top-1 are kept as `best.pt`.

With `--decoder`, a decoder run over the base encoder is fine-tuned together with it: the
ranking loss is taken on the decoder's emissions and both learn. The new run then holds
`best.pt` and `decoder.pt` (whose encoder is the run itself), and uses the decoder run's
tuned scoring."""

import argparse
import json
import math
import time
from pathlib import Path

import numpy as np
import torch

from augment import AugmentConfig, augment_geometry
from decode import Pruning, beam_search
from decoder_model import DecoderConfig, SwipeDecoder
from emissions import compute_frames, load_encoder
from evaluate import decode_accuracy, target_forms
from layouts import load_layout
from lexicon import build_trie, load_lexicon
from model import key_basis, log_emissions
from prepare_swipes import POINTS
from ranking import lexicon_paths, ranking_loss, ranking_options
from run_emissions import DECODER_CHECKPOINT
from run_settings import KEEP_DOUBLES, keeps_doubles
from scoring import Scoring, candidate_scores
from train import output_frames

WEIGHT_DECAY = 1e-4
GRADIENT_CLIP = 1.0
WARMUP_FRACTION = 0.05
DECODE_BATCH = 4096


def pipeline_emissions(model, decoder, xy: np.ndarray, layout, device) -> np.ndarray:
    """The encoder's emissions, passed through the decoder when there is one."""
    frames = compute_frames(model, xy, layout, device)
    if decoder is None:
        return frames[..., : len(layout.letters) + 1]
    with torch.no_grad():
        return np.concatenate([decoder(torch.from_numpy(frames[start:start + DECODE_BATCH]).to(device)).cpu().numpy()
                               for start in range(0, len(frames), DECODE_BATCH)])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("base_run")
    parser.add_argument("run")
    parser.add_argument("lexicon", type=Path)
    parser.add_argument("--epochs", type=int, default=4)
    parser.add_argument("--batch", type=int, default=1024)
    parser.add_argument("--learning-rate", type=float, default=1e-4)
    parser.add_argument("--limit", type=int, default=0, help="train on only the first N swipes")
    parser.add_argument("--keep-doubles", action="store_true", help="switch the run to key paths that keep repeated keys")
    parser.add_argument("--decoder", help="a decoder run over the base encoder, fine-tuned together with it")
    parser.add_argument("--device", default="mps" if torch.backends.mps.is_available() else "cpu")
    parser.add_argument("--seed", type=int, default=0)
    arguments = parser.parse_args()

    torch.manual_seed(arguments.seed)
    device = torch.device(arguments.device)
    models = arguments.data_dir / "models"
    base_dir, run_dir = models / arguments.base_run, models / arguments.run
    run_dir.mkdir(parents=True, exist_ok=True)
    base_settings = json.loads((base_dir / "settings.json").read_text())
    decoder, decoder_state = None, None
    if arguments.decoder:
        decoder_state = torch.load(models / arguments.decoder / DECODER_CHECKPOINT, map_location=device)
        if decoder_state["encoder_run"] != arguments.base_run:
            parser.error(f"{arguments.decoder} decodes {decoder_state['encoder_run']}, not {arguments.base_run}")
        decoder = SwipeDecoder(DecoderConfig(**decoder_state["config"])).to(device)
        decoder.load_state_dict(decoder_state["model"])
    scoring = Scoring.load((models / arguments.decoder if decoder else base_dir) / "scoring.json")
    augment_config = AugmentConfig(**{**base_settings["augment"], "y_scale": tuple(base_settings["augment"]["y_scale"]),
                                      "x_scale": tuple(base_settings["augment"]["x_scale"])})
    pruning = Pruning()
    layout = load_layout(arguments.data_dir, base_settings["layout"])
    lexicon = load_lexicon(arguments.lexicon)
    keep_doubles = keeps_doubles(base_settings) or arguments.keep_doubles
    trie = build_trie(lexicon, layout, keep_doubles)
    model = load_encoder(base_dir / "best.pt", device)

    prepared = arguments.data_dir / "prepared"
    names = ["train.npz"] + (["extra.npz"] if base_settings["extra"] else [])
    xy = np.concatenate([np.load(prepared / name)["xy"] for name in names])
    forms = np.concatenate([np.load(prepared / name)["form"] for name in names])
    if arguments.limit:
        xy, forms = xy[: arguments.limit], forms[: arguments.limit]
    targets = target_forms(forms, lexicon.forms)
    model.eval()
    if decoder:
        decoder.eval()
    candidates = beam_search(arguments.data_dir, pipeline_emissions(model, decoder, xy, layout, device), trie, pruning)
    scores = candidate_scores(candidates, lexicon.frequency, trie.form_path_length, scoring)
    paths, path_lengths = lexicon_paths(lexicon, layout.key_index, output_frames(POINTS), keep_doubles)
    options, keep = ranking_options(candidates, scores, targets, path_lengths)
    del candidates, scores
    print(f"fine-tuning swipes: {keep.sum()} of {len(keep)}", flush=True)

    train_xy = torch.from_numpy(xy[keep]).to(device)
    train_options = torch.from_numpy(options[keep]).to(device)
    val = np.load(prepared / "val.npz")
    val_targets = target_forms(val["form"], lexicon.forms)
    paths_t, lengths_t = torch.from_numpy(paths), torch.from_numpy(path_lengths)
    frequency = torch.from_numpy(lexicon.frequency).to(device)
    centers = torch.from_numpy(layout.centers).to(device)

    parameters = list(model.parameters()) + (list(decoder.parameters()) if decoder else [])
    optimizer = torch.optim.AdamW(parameters, lr=arguments.learning_rate, weight_decay=WEIGHT_DECAY)
    steps_per_epoch = len(train_xy) // arguments.batch
    total = steps_per_epoch * arguments.epochs
    warmup = max(1, int(total * WARMUP_FRACTION))
    settings = {**base_settings, KEEP_DOUBLES: keep_doubles, "finetune": {**vars(arguments), "data_dir": str(arguments.data_dir),
                                              "lexicon": str(arguments.lexicon), "scoring": scoring.__dict__}}
    (run_dir / "settings.json").write_text(json.dumps(settings, indent=2) + "\n")

    _, _, accuracy = decode_accuracy(arguments.data_dir, pipeline_emissions(model, decoder, val["xy"], layout, device),
                                     trie, lexicon, scoring, val_targets, pruning)
    print(json.dumps({"epoch": -1, **{f"val_{k}": v for k, v in accuracy.items()}}), flush=True)
    best = accuracy["top1"]
    def save() -> None:
        torch.save({"model": model.state_dict(), "config": model.config.to_dict(), "layout": layout.name},
                   run_dir / "best.pt")
        if decoder:
            torch.save({**decoder_state, "model": decoder.state_dict(), "encoder_run": arguments.run},
                       run_dir / DECODER_CHECKPOINT)

    save()
    for epoch in range(arguments.epochs):
        model.train()
        if decoder:
            decoder.train()
        started = time.time()
        order = torch.randperm(len(train_xy), device=device)
        total_loss = 0.0
        for batch_number in range(steps_per_epoch):
            step = epoch * steps_per_epoch + batch_number
            rate = (step + 1) / warmup if step < warmup else 0.5 * (1 + math.cos(math.pi * (step - warmup) / max(1, total - warmup)))
            for group in optimizer.param_groups:
                group["lr"] = arguments.learning_rate * rate
            index = order[batch_number * arguments.batch:(batch_number + 1) * arguments.batch]
            batch = len(index)
            keys = centers.expand(batch, -1, -1)
            key_mask = torch.ones(batch, keys.shape[1], dtype=torch.bool, device=device)
            swipes, keys = augment_geometry(train_xy[index], keys, key_mask, augment_config)
            coefficients, gate = model(swipes)
            emissions = log_emissions(coefficients, gate, key_basis(keys, model.config.basis), key_mask)
            if decoder:
                emissions = decoder(torch.cat([emissions, coefficients, torch.sigmoid(gate).unsqueeze(2)], dim=2))
            loss = ranking_loss(emissions, train_options[index], paths_t, lengths_t, frequency, scoring)
            optimizer.zero_grad(set_to_none=True)
            loss.backward()
            torch.nn.utils.clip_grad_norm_(parameters, GRADIENT_CLIP)
            optimizer.step()
            total_loss += loss.item()

        model.eval()
        if decoder:
            decoder.eval()
        _, _, accuracy = decode_accuracy(arguments.data_dir, pipeline_emissions(model, decoder, val["xy"], layout, device),
                                         trie, lexicon, scoring, val_targets, pruning)
        record = {"epoch": epoch, "loss": total_loss / steps_per_epoch,
                  **{f"val_{k}": v for k, v in accuracy.items()}, "seconds": time.time() - started}
        with open(run_dir / "log.jsonl", "a") as log:
            log.write(json.dumps(record) + "\n")
        print(json.dumps(record), flush=True)
        if accuracy["top1"] > best:
            best = accuracy["top1"]
            save()


if __name__ == "__main__":
    main()
