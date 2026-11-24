"""Turns the swipe recordings into model-ready arrays under `prepared/`.

Each swipe is resampled to a fixed number of points spaced evenly in time, in the
keyboard's normalized frame. Each output file holds `xy` [N, points, 2], the target word's
`form` (see `words.letter_form`), its `word` as recorded, the recording's `distance`, and
its `layout`.

- `train`, `val`, `test`: swipe.futo.org's first run and its official splits, unfiltered.
- `extra`: the later English QWERTY runs (swipe-2 to swipe-5, one finger only). They are
  released unfiltered, so swipes whose `distance` is unscored or beyond the first run's
  filtered distribution are dropped. Other languages and layouts are never written here."""

import argparse
import json
from multiprocessing import Pool
from pathlib import Path

import numpy as np

from words import letter_form

POINTS = 64
FUTO = Path("sources/futo-swipe")
FIRST_RUN_SPLITS = {"train": "train.jsonl", "val": "dev.jsonl", "test": "test.jsonl"}
LATER_RUNS = ("swipe-2/swipe2.jsonl", "swipe-3/swipe3.jsonl", "swipe-4/swipe4.jsonl", "swipe-5/swipe5.jsonl")
ENGLISH = "en"
QWERTY = "qwerty"
# The later runs are kept up to this percentile of the first run's scored training distances.
EXTRA_DISTANCE_PERCENTILE = 99.0
# The recordings give swipes they could not score a distance of this or more.
UNSCORED_DISTANCE = 100_000.0
BATCH_LINES = 20_000


def resample(points: list[dict], count: int = POINTS) -> np.ndarray:
    """`count` points spaced evenly in time, linearly interpolated."""
    if not points:
        return np.zeros((count, 2), dtype=np.float32)
    ordered = sorted(points, key=lambda point: point["t"])
    t = np.array([point["t"] for point in ordered], dtype=np.float64)
    x = np.array([point["x"] for point in ordered], dtype=np.float64)
    y = np.array([point["y"] for point in ordered], dtype=np.float64)
    if t[-1] <= t[0]:
        return np.repeat(np.array([[x.mean(), y.mean()]], dtype=np.float32), count, axis=0)
    targets = np.linspace(t[0], t[-1], count)
    return np.stack([np.interp(targets, t, x), np.interp(targets, t, y)], axis=1).astype(np.float32)


def _parse(lines: list[str]) -> list[tuple]:
    rows = []
    for line in lines:
        record = json.loads(line)
        if not isinstance(record["data"], list):
            continue
        rows.append((
            resample(record["data"]),
            record["word"],
            float(record.get("distance", 0.0)),
            record.get("layout", QWERTY),
            record.get("language", ENGLISH),
            int(record.get("dual_finger", 0)),
        ))
    return rows


def _batches(path: Path):
    with open(path) as file:
        batch = []
        for line in file:
            batch.append(line)
            if len(batch) == BATCH_LINES:
                yield batch
                batch = []
        if batch:
            yield batch


def read_rows(path: Path, pool: Pool) -> list[tuple]:
    rows = []
    for parsed in pool.imap(_parse, _batches(path)):
        rows.extend(parsed)
    return rows


def write(path: Path, rows: list[tuple]) -> None:
    np.savez(
        path,
        xy=np.stack([row[0] for row in rows]),
        word=np.array([row[1] for row in rows]),
        form=np.array([letter_form(row[1]) for row in rows]),
        distance=np.array([row[2] for row in rows], dtype=np.float32),
        layout=np.array([row[3] for row in rows]),
    )
    print(f"wrote {path} ({len(rows)} swipes)", flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    output = arguments.data_dir / "prepared"
    output.mkdir(exist_ok=True)

    with Pool() as pool:
        train_distances = None
        for split, name in FIRST_RUN_SPLITS.items():
            rows = read_rows(arguments.data_dir / FUTO / name, pool)
            if split == "train":
                train_distances = np.array([row[2] for row in rows if row[2] < UNSCORED_DISTANCE])
            write(output / f"{split}.npz", rows)

        limit = float(np.percentile(train_distances, EXTRA_DISTANCE_PERCENTILE))
        extra = []
        for name in LATER_RUNS:
            rows = read_rows(arguments.data_dir / FUTO / name, pool)
            kept = [
                row for row in rows
                if row[3] == QWERTY and row[4] == ENGLISH and row[5] == 0 and row[2] <= limit
            ]
            print(f"{name}: kept {len(kept)} of {len(rows)} (distance <= {limit:.1f})", flush=True)
            extra.extend(kept)
        write(output / "extra.npz", extra)


if __name__ == "__main__":
    main()
