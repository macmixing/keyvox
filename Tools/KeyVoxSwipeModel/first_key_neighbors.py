"""Finds each lexicon form's first-key neighbors: the forms whose key paths are the same
after the first key and start on the key beside it in its row. The rest of a swipe is the
same for a word and its first-key neighbors, so only where the swipe lands tells them apart."""

from collections import defaultdict

import numpy as np

from layouts import Layout

# How far past one key pitch two centers in a row may be and still count as side by side.
_PITCH_TOLERANCE = 1.01


def beside_keys(layout: Layout) -> list[set[int]]:
    """For each key, the keys beside it in its row: same row, one key pitch away."""
    centers = layout.centers
    beside: list[set[int]] = [set() for _ in centers]
    for key, (x, y) in enumerate(centers):
        row = [other for other, (_, other_y) in enumerate(centers) if other != key and other_y == y]
        if not row:
            continue
        pitch = min(abs(centers[other][0] - x) for other in row)
        beside[key] = {other for other in row if abs(centers[other][0] - x) <= pitch * _PITCH_TOLERANCE}
    return beside


def first_key_neighbors(paths: np.ndarray, lengths: np.ndarray, layout: Layout) -> list[list[int]]:
    """Per form, the forms that are its first-key neighbors. `paths` and `lengths` are
    `ranking.lexicon_paths`'s: CTC labels (key + 1) and each path's length, 0 for none."""
    beside = beside_keys(layout)
    by_rest: dict[tuple[int, ...], dict[int, list[int]]] = defaultdict(lambda: defaultdict(list))
    for form, length in enumerate(lengths):
        if length > 0:
            by_rest[tuple(paths[form, 1:length])][int(paths[form, 0]) - 1].append(form)
    neighbors: list[list[int]] = [[] for _ in lengths]
    for starts in by_rest.values():
        for key, forms in starts.items():
            others = [other for near in beside[key] if near in starts for other in starts[near]]
            if others:
                for form in forms:
                    neighbors[form] = others
    return neighbors
