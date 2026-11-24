"""Ranks a swipe's decoded candidates and measures top-k accuracy.

A candidate word w with key-path length L, CTC log-probability log p, and dictionary
probability f (0-255, already log-scaled) scores

    log p / L^gamma + frequency_weight * f + length_bonus * L"""

import json
from dataclasses import asdict, dataclass
from pathlib import Path

import numpy as np

from decode import Candidates

TOP_K = (1, 3, 10)


@dataclass(frozen=True)
class Scoring:
    gamma: float = 0.105
    frequency_weight: float = 0.05
    length_bonus: float = 2.488

    def save(self, path: Path) -> None:
        path.write_text(json.dumps(asdict(self), indent=2) + "\n")

    @staticmethod
    def load(path: Path) -> "Scoring":
        return Scoring(**json.loads(path.read_text()))


def candidate_scores(
    candidates: Candidates, frequency: np.ndarray, path_length: np.ndarray, scoring: Scoring
) -> np.ndarray:
    length = path_length[candidates.form].astype(np.float32)
    return (
        candidates.log_probability / np.power(np.maximum(length, 1.0), scoring.gamma)
        + scoring.frequency_weight * frequency[candidates.form]
        + scoring.length_bonus * length
    )


def target_ranks(candidates: Candidates, scores: np.ndarray, targets: np.ndarray) -> np.ndarray:
    """0-based rank of each swipe's target form among its candidates, or infinity when the
    target is not a candidate. `targets` holds lexicon
    form indices, -1 for words the lexicon lacks."""
    count = len(candidates.start) - 1
    group = np.repeat(np.arange(count), np.diff(candidates.start))
    is_target = candidates.form == targets[group]
    target_score = np.full(count, -np.inf, dtype=np.float64)
    target_score[group[is_target]] = scores[is_target]
    better = np.bincount(group, weights=scores > target_score[group], minlength=count)
    return np.where(np.isfinite(target_score), better, np.inf)


def top_k_accuracy(ranks: np.ndarray) -> dict[str, float]:
    return {f"top{k}": float((ranks < k).mean() * 100) for k in TOP_K}
