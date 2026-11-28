"""Moves a swipe recorded on one keyboard layout onto another, so swipes of one layout teach the
encoder another layout's keys.

Each key of the word's key path is matched to the point where the swipe passes it: the points
are chosen in order, each key's at or after the last one's, to make the summed distance from
each key's center to its point the least. At each matched point the swipe moves by how far that
key's letter moves between the layouts; between two matched points the move is blended linearly
over the points between them, and before the first and after the last it is the first and the
last key's. The person's own path around and between the keys is kept: only where it goes moves.
"""

import numpy as np

from layouts import Layout


def matched_points(path: np.ndarray, centers: np.ndarray) -> np.ndarray:
    """For each of `centers` [K, 2] in order, the index of its point of `path` [T, 2], nondecreasing,
    with the least summed distance."""
    distance = np.linalg.norm(path[None, :, :] - centers[:, None, :], axis=2)  # [K, T]
    keys, points = distance.shape
    cost = np.empty((keys, points))
    choice = np.empty((keys, points), dtype=np.int64)
    cost[0] = distance[0]
    indices = np.arange(points)
    for key in range(1, keys):
        # The earlier key's best cost at any point up to each one, and the last point it is at.
        best = np.minimum.accumulate(cost[key - 1])
        choice[key] = np.maximum.accumulate(np.where(cost[key - 1] <= best, indices, 0))
        cost[key] = best + distance[key]
    matched = np.empty(keys, dtype=np.int64)
    matched[-1] = int(np.argmin(cost[-1]))
    for key in range(keys - 1, 0, -1):
        matched[key - 1] = choice[key, matched[key]]
    return matched


def warp(path: np.ndarray, letters: str, source: Layout, target: Layout) -> np.ndarray:
    """`path` [T, 2], a swipe of the key path `letters` on `source`, moved onto `target`; every
    letter must have a key on both."""
    source_centers = source.centers[[source.key_index[letter] for letter in letters]]
    target_centers = target.centers[[target.key_index[letter] for letter in letters]]
    matched = matched_points(path, source_centers)
    moves = target_centers - source_centers
    times = np.arange(len(path))
    # A key path passing two keys at one point takes the later key's move there.
    unique, last = np.unique(matched[::-1], return_index=True)
    rows = len(matched) - 1 - last
    shift = np.stack([np.interp(times, unique, moves[rows, axis]) for axis in range(2)], axis=1)
    return (path + shift).astype(np.float32)
