"""Decodes a split with a trained encoder and reports top-1 / top-3 / top-10 accuracy.

Every swipe in the split counts, including words the lexicon lacks (always a miss). A
prediction is correct when its swipe form (`words.letter_form`) equals the recorded word's.
The run may be an encoder run or a decoder run (`train_decoder.py`). With `--exported`,
emissions come from the run's exported fp16 files run by `exported_model.py` instead of
the PyTorch checkpoints. Candidates are cached in `models/<run>/candidates-<split>.npz`
for `tune_scoring.py`; results go to `models/<run>/results-<split>.json`."""

import argparse
import json
from pathlib import Path

import numpy as np
import torch

from decode import Pruning, beam_search, save_candidates
from layouts import load_layout
from lexicon import build_trie, load_lexicon
from run_emissions import run_emissions
from scoring import Scoring, candidate_scores, target_ranks, top_k_accuracy


def target_forms(forms: np.ndarray, lexicon_forms: tuple[str, ...]) -> np.ndarray:
    index = {form: number for number, form in enumerate(lexicon_forms)}
    return np.array([index.get(str(form), -1) for form in forms], dtype=np.int32)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("run")
    parser.add_argument("lexicon", type=Path, help="unigram dump of the bundled dictionary")
    parser.add_argument("--split", default="val", choices=("val", "test"))
    parser.add_argument("--checkpoint", default="best.pt")
    parser.add_argument("--exported", action="store_true", help="decode with the run's exported fp16 files")
    parser.add_argument("--layout", default="qwerty")
    parser.add_argument("--beam", type=int, default=Pruning.beam)
    parser.add_argument("--prune-gamma", type=float, default=Pruning.gamma)
    parser.add_argument("--prune-beta", type=float, default=Pruning.beta)
    arguments = parser.parse_args()

    run_dir = arguments.data_dir / "models" / arguments.run
    device = torch.device("mps" if torch.backends.mps.is_available() else "cpu")
    layout = load_layout(arguments.data_dir, arguments.layout)
    lexicon = load_lexicon(arguments.lexicon)
    trie = build_trie(lexicon, layout)
    split = np.load(arguments.data_dir / "prepared" / f"{arguments.split}.npz")

    emissions = run_emissions(arguments.data_dir / "models", arguments.run, split["xy"], layout, device,
                              arguments.exported, arguments.checkpoint)
    pruning = Pruning(beam=arguments.beam, gamma=arguments.prune_gamma, beta=arguments.prune_beta)
    candidates = beam_search(arguments.data_dir, emissions, trie, pruning)
    save_candidates(run_dir / f"candidates-{arguments.split}.npz", candidates, pruning)

    scoring_path = run_dir / "scoring.json"
    scoring = Scoring.load(scoring_path) if scoring_path.exists() else Scoring()
    targets = target_forms(split["form"], lexicon.forms)
    ranks = target_ranks(candidates, candidate_scores(candidates, lexicon.frequency, trie.form_path_length, scoring), targets)
    in_beam = np.isfinite(ranks)
    results = {
        "split": arguments.split,
        "swipes": int(len(targets)),
        "in_lexicon": float((targets >= 0).mean() * 100),
        "in_beam": float(in_beam.mean() * 100),
        **top_k_accuracy(ranks),
        "exported": arguments.exported,
        "checkpoint": arguments.checkpoint,
        "pruning": pruning.__dict__,
        "scoring": scoring.__dict__,
    }
    (run_dir / f"results-{arguments.split}.json").write_text(json.dumps(results, indent=2) + "\n")
    print(json.dumps(results, indent=2))


if __name__ == "__main__":
    main()
