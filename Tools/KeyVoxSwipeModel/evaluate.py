"""Decodes a split with a trained encoder and reports top-1 / top-3 / top-10 accuracy.

Every swipe in the split counts, including words the lexicon lacks (always a miss). A
prediction is correct when its swipe form (`words.letter_form`) equals the recorded word's.
Each swipe is decoded on the layout it was recorded on; the `layouts` split (English on
layouts other than QWERTY) also reports each layout, and needs an encoder run, since the
decoder is trained for one layout.
The run may be an encoder run or a decoder run (`train_decoder.py`). With `--exported`,
emissions come from the run's exported fp16 files run by `exported_model.py` instead of
the PyTorch checkpoints. Candidates are cached in `models/<run>/candidates-<split>.npz`
for `tune_scoring.py` (single-layout splits only); results go to `models/<run>/results-<split>.json`."""

import argparse
import json
from pathlib import Path

import numpy as np
import torch

from decode import Pruning, beam_search, save_candidates
from layouts import load_layout
from lexicon import build_trie, load_lexicon
from run_emissions import is_decoder_run, run_emissions
from run_settings import encoder_settings, keeps_doubles
from scoring import Scoring, candidate_scores, target_ranks, top_k_accuracy


def target_forms(forms: np.ndarray, lexicon_forms: tuple[str, ...]) -> np.ndarray:
    index = {form: number for number, form in enumerate(lexicon_forms)}
    return np.array([index.get(str(form), -1) for form in forms], dtype=np.int32)


def decode_accuracy(data_dir: Path, emissions: np.ndarray, trie, lexicon, scoring: Scoring, targets: np.ndarray,
                    pruning: Pruning) -> tuple:
    """Beam-searches emissions and returns the candidates, each swipe's target rank, and top-k accuracy."""
    candidates = beam_search(data_dir, emissions, trie, pruning)
    ranks = target_ranks(candidates, candidate_scores(candidates, lexicon.frequency, trie.form_path_length, scoring), targets)
    return candidates, ranks, top_k_accuracy(ranks)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("run")
    parser.add_argument("lexicon", type=Path, help="unigram dump of the bundled dictionary")
    parser.add_argument("--split", default="val", choices=("val", "test", "layouts"))
    parser.add_argument("--checkpoint", default="best.pt")
    parser.add_argument("--exported", action="store_true", help="decode with the run's exported fp16 files")
    parser.add_argument("--beam", type=int, default=Pruning.beam)
    parser.add_argument("--prune-gamma", type=float, default=Pruning.gamma)
    parser.add_argument("--prune-beta", type=float, default=Pruning.beta)
    arguments = parser.parse_args()

    run_dir = arguments.data_dir / "models" / arguments.run
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    lexicon = load_lexicon(arguments.lexicon)
    split = np.load(arguments.data_dir / "prepared" / f"{arguments.split}.npz")
    layout_names = sorted(set(split["layout"].tolist()))
    if len(layout_names) > 1 and is_decoder_run(run_dir):
        parser.error(f"the {arguments.split} split spans several layouts and needs an encoder run")
    keep_doubles = keeps_doubles(encoder_settings(arguments.data_dir / "models", arguments.run))
    pruning = Pruning(beam=arguments.beam, gamma=arguments.prune_gamma, beta=arguments.prune_beta)
    scoring_path = run_dir / "scoring.json"
    scoring = Scoring.load(scoring_path) if scoring_path.exists() else Scoring()
    targets = target_forms(split["form"], lexicon.forms)

    ranks = np.full(len(targets), np.inf)
    per_layout = {}
    for name in layout_names:
        rows = np.flatnonzero(split["layout"] == name)
        layout = load_layout(arguments.data_dir, name)
        emissions = run_emissions(arguments.data_dir / "models", arguments.run, split["xy"][rows], layout, device,
                                  arguments.exported, arguments.checkpoint)
        candidates, ranks[rows], accuracy = decode_accuracy(
            arguments.data_dir, emissions, build_trie(lexicon, layout, keep_doubles), lexicon, scoring, targets[rows], pruning)
        per_layout[name] = {"swipes": int(len(rows)), **accuracy}
        if len(layout_names) == 1:
            save_candidates(run_dir / f"candidates-{arguments.split}.npz", candidates, pruning)
    accuracy = top_k_accuracy(ranks)
    in_beam = np.isfinite(ranks)
    results = {
        "split": arguments.split,
        "swipes": int(len(targets)),
        "in_lexicon": float((targets >= 0).mean() * 100),
        "in_beam": float(in_beam.mean() * 100),
        **accuracy,
        **({"layouts": per_layout} if len(layout_names) > 1 else {}),
        "exported": arguments.exported,
        "checkpoint": arguments.checkpoint,
        "pruning": pruning.__dict__,
        "scoring": scoring.__dict__,
    }
    (run_dir / f"results-{arguments.split}.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
