"""Writes English swipes moved onto the keyboard's other letter layouts, for fine-tuning an
encoder on them (`rank_layouts.py`).

Each swipe of `prepared/<split>.npz` (swipe.futo.org's swipes on its QWERTY) is given one of
`--layouts` (`PredictiveData/letter_layouts`), chosen by a seeded random draw, and moved onto
it (`layout_warp.warp`); a swipe given `QWERTY` stays as recorded, on swipe.futo.org's QWERTY
(`qwerty`), whose geometry its points belong to.
Words whose letters are not all keys of both layouts are left out. Writes
`prepared/<output>-<split>.npz` with `xy`, `form`, `word`, and each swipe's `layout`.

    python warp_layout_swipes.py <data-dir> layouts --layouts QWERTY,QWERTZ-German,AZERTY-French"""

import argparse
from multiprocessing import Pool
from os import cpu_count
from pathlib import Path

import numpy as np

from layout_warp import warp
from layouts import load_layout, load_letter_layout
from words import key_path

SOURCE_LAYOUT = "qwerty"
KEPT_LAYOUT = "QWERTY"
SPLITS = {"train": ("train.npz", "extra.npz"), "val": ("val.npz",)}
WORKERS = max(1, (cpu_count() or 1) - 2)

_source = None
_targets = None


def _start(data_dir: Path, names: list[str]) -> None:
    global _source, _targets
    _source = load_layout(data_dir, SOURCE_LAYOUT)
    _targets = {name: load_letter_layout(name) for name in names}


def _warp(job: tuple[np.ndarray, str, str]) -> np.ndarray | None:
    xy, form, name = job
    target = _targets[name]
    path = key_path(form, _source.key_index)
    if not path or any(letter not in target.key_index for letter in form):
        return None
    if name == KEPT_LAYOUT:
        return xy
    return warp(xy, "".join(_source.letters[key] for key in path), _source, target)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("output")
    parser.add_argument("--layouts", required=True, help="comma-separated letter layout names")
    parser.add_argument("--seed", type=int, default=0)
    arguments = parser.parse_args()
    names = arguments.layouts.split(",")
    prepared = arguments.data_dir / "prepared"
    generator = np.random.default_rng(arguments.seed)
    with Pool(WORKERS, initializer=_start, initargs=(arguments.data_dir, names)) as pool:
        for split, files in SPLITS.items():
            data = [np.load(prepared / name) for name in files]
            xy = np.concatenate([item["xy"] for item in data])
            forms = np.concatenate([item["form"] for item in data])
            words = np.concatenate([item["word"] for item in data])
            chosen = np.array(names)[generator.integers(len(names), size=len(xy))]
            moved = pool.map(_warp, zip(xy, map(str, forms), chosen), chunksize=2048)
            keep = np.array([path is not None for path in moved])
            np.savez(
                prepared / f"{arguments.output}-{split}.npz",
                xy=np.stack([path for path in moved if path is not None]),
                form=forms[keep], word=words[keep],
                layout=np.where(chosen[keep] == KEPT_LAYOUT, SOURCE_LAYOUT, chosen[keep]),
            )
            print(f"wrote {arguments.output}-{split}.npz: {keep.sum()} of {len(keep)} swipes, "
                  + ", ".join(f"{name} {(chosen[keep] == name).sum()}" for name in names), flush=True)


if __name__ == "__main__":
    main()
