"""Reads a keyboard layout: each letter key's center and half-size in the keyboard's
normalized frame, where the keyboard spans 0 to 1 on both axes."""

import json
from dataclasses import dataclass
from pathlib import Path

import numpy as np

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


def load_layout(data_dir: Path, name: str) -> Layout:
    document = json.loads((data_dir / LAYOUT_DIRECTORY / f"{name}.json").read_text())
    keys = document["keys"]
    return Layout(
        name=document["name"],
        letters=tuple(key["letter"] for key in keys),
        centers=np.array([[key["cx"], key["cy"]] for key in keys], dtype=np.float32),
        radii=np.array([[key["rx"], key["ry"]] for key in keys], dtype=np.float32),
    )
