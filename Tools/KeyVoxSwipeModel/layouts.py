"""Reads a keyboard layout: each letter key's center and half-size in the keyboard's
normalized frame, where the keyboard spans 0 to 1 on both axes: a swipe.futo.org layout file, or
one of the keyboard's own letter layouts (`PredictiveData/letter_layouts/<name>.json`), placed
as the keyboard's `LetterKeyLayout.defaultGeometry` and `SwipeKeyboardFrame` place it for the
model: every key one unit wide and tall, rows one unit apart, the letter keys spanning the frame."""

import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from words import PREDICTIVE_DATA

LAYOUT_DIRECTORY = Path("sources/futo-swipe/swipe-5/layouts")


@dataclass(frozen=True)
class Layout:
    name: str
    letters: tuple[str, ...]
    centers: np.ndarray  # [K, 2] float32, x then y
    radii: np.ndarray  # [K, 2] float32, half width then half height

    @property
    def key_index(self) -> dict[str, int]:
        return {letter: index for index, letter in enumerate(self.letters)}


LETTER_LAYOUTS = PREDICTIVE_DATA / "letter_layouts"


def load_letter_layout(name: str, directory: Path = LETTER_LAYOUTS) -> Layout:
    """One of the keyboard's letter layouts, under its own name (such as `QWERTZ-German`)."""
    rows = json.loads((directory / f"{name}.json").read_text(encoding="utf-8"))["rows"]
    keys = []
    for row_number, items in enumerate(rows):
        x = 0.0
        for item in items:
            if "characters" in item:
                for character in item["characters"]:
                    if character.isalpha():
                        keys.append((character.lower(), x, row_number))
                    x += 1
            else:
                x += next(iter(item.values()))
    width = max(x for _, x, _ in keys) + 1
    height = max(row for _, _, row in keys) + 1
    return Layout(
        name=name,
        letters=tuple(letter for letter, _, _ in keys),
        centers=np.array([[(x + 0.5) / width, (row + 0.5) / height] for _, x, row in keys], dtype=np.float32),
        radii=np.array([[0.5 / width, 0.5 / height] for _ in keys], dtype=np.float32),
    )


def load_layout(data_dir: Path, name: str) -> Layout:
    document = json.loads((data_dir / LAYOUT_DIRECTORY / f"{name}.json").read_text())
    keys = document["keys"]
    return Layout(
        name=document["name"],
        letters=tuple(key["letter"] for key in keys),
        centers=np.array([[key["cx"], key["cy"]] for key in keys], dtype=np.float32),
        radii=np.array([[key["rx"], key["ry"]] for key in keys], dtype=np.float32),
    )
