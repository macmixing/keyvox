"""Loads prepared swipes with their CTC targets for one layout."""

from dataclasses import dataclass
from pathlib import Path

import numpy as np

from layouts import Layout
from words import key_path


@dataclass(frozen=True)
class Swipes:
    xy: np.ndarray  # [N, T, 2] float32
    forms: np.ndarray  # [N] str
    targets: np.ndarray  # [N, max_path] int64, key + 1 (0 is the CTC blank), zero padded
    lengths: np.ndarray  # [N] int64, 0 when the word cannot be swiped on this layout


def load_swipes(paths: list[Path], layout: Layout, max_path: int) -> Swipes:
    """Every prepared swipe in `paths`; words longer than `max_path` keys get length 0."""
    key_index = layout.key_index
    xy, forms = [], []
    for path in paths:
        data = np.load(path)
        xy.append(data["xy"])
        forms.append(data["form"])
    xy_all = np.concatenate(xy)
    forms_all = np.concatenate(forms)
    targets = np.zeros((len(forms_all), max_path), dtype=np.int64)
    lengths = np.zeros(len(forms_all), dtype=np.int64)
    for row, form in enumerate(forms_all):
        keys = key_path(str(form), key_index)
        if keys and len(keys) <= max_path:
            targets[row, : len(keys)] = np.array(keys) + 1
            lengths[row] = len(keys)
    return Swipes(xy=xy_all, forms=forms_all, targets=targets, lengths=lengths)


def trainable(swipes: Swipes) -> Swipes:
    keep = swipes.lengths > 0
    return Swipes(
        xy=swipes.xy[keep], forms=swipes.forms[keep], targets=swipes.targets[keep], lengths=swipes.lengths[keep]
    )
