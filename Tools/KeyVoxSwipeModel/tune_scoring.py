"""Tunes the rescoring weights on the validation split's cached candidates and writes
them to `models/<run>/scoring.json`.

Run `evaluate.py --split val` first. The search maximizes validation top-1 (top-3 breaks
ties): a seeded random search over the weight ranges, then coordinate refinement around
the best point with shrinking steps."""

import argparse
import json
from pathlib import Path

import numpy as np

from decode import load_candidates
from evaluate import target_forms
from layouts import load_layout
from lexicon import build_trie, load_lexicon
from scoring import Scoring, candidate_scores, target_ranks, top_k_accuracy

RANGES = {"gamma": (0.0, 1.0), "frequency_weight": (0.0, 0.2), "length_bonus": (0.0, 6.0)}
RANDOM_TRIALS = 400
REFINE_ROUNDS = 6


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("run")
    parser.add_argument("lexicon", type=Path)
    parser.add_argument("--layout", default="qwerty")
    parser.add_argument("--seed", type=int, default=0)
    arguments = parser.parse_args()

    run_dir = arguments.data_dir / "models" / arguments.run
    lexicon = load_lexicon(arguments.lexicon)
    trie = build_trie(lexicon, load_layout(arguments.data_dir, arguments.layout))
    candidates, _ = load_candidates(run_dir / "candidates-val.npz")
    targets = target_forms(np.load(arguments.data_dir / "prepared" / "val.npz")["form"], lexicon.forms)

    def measure(values: dict) -> tuple[float, float]:
        scores = candidate_scores(candidates, lexicon.frequency, trie.form_path_length, Scoring(**values))
        accuracy = top_k_accuracy(target_ranks(candidates, scores, targets))
        return accuracy["top1"], accuracy["top3"]

    generator = np.random.default_rng(arguments.seed)
    best_values = Scoring().__dict__.copy()
    best = measure(best_values)
    for _ in range(RANDOM_TRIALS):
        values = {name: float(generator.uniform(*bounds)) for name, bounds in RANGES.items()}
        result = measure(values)
        if result > best:
            best, best_values = result, values

    steps = {name: (high - low) / 10 for name, (low, high) in RANGES.items()}
    for _ in range(REFINE_ROUNDS):
        improved = True
        while improved:
            improved = False
            for name, (low, high) in RANGES.items():
                for direction in (-1, 1):
                    values = {**best_values, name: float(np.clip(best_values[name] + direction * steps[name], low, high))}
                    result = measure(values)
                    if result > best:
                        best, best_values, improved = result, values, True
        steps = {name: step / 2 for name, step in steps.items()}

    Scoring(**best_values).save(run_dir / "scoring.json")
    print(json.dumps({"scoring": best_values, "val_top1": best[0], "val_top3": best[1]}, indent=2))


if __name__ == "__main__":
    main()
