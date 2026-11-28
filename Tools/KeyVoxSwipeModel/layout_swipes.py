"""Loads prepared swipes of several keyboard layouts as tensors for fine-tuning: each swipe's points,
its word's form, its CTC targets on its own layout's keys, and its layout's number.

A prepared array names each swipe's layout (`warp_layout_swipes.py`): one of the keyboard's
letter layouts (`PredictiveData/letter_layouts`) or else a swipe.futo.org layout file. A name in
`specs` may end in `:<times>`, its swipes counted that many times. Swipes whose key path does not
fit the model's frames are left out. Batches hold the swipes of one layout, so every swipe in a
batch is scored on the same keys."""

from pathlib import Path

import numpy as np
import torch

from layouts import LETTER_LAYOUTS, Layout, load_layout, load_letter_layout
from prepare_swipes import POINTS
from train import output_frames
from words import ctc_frames_needed, key_path


def resolve_layout(data_dir: Path, name: str) -> Layout:
    if (LETTER_LAYOUTS / f"{name}.json").exists():
        return load_letter_layout(name)
    return load_layout(data_dir, name)


def layout_names(data_dir: Path, specs: list[str]) -> set[str]:
    names: set[str] = set()
    for spec in specs:
        names.update(np.load(data_dir / "prepared" / f"{spec.partition(':')[0]}.npz")["layout"].tolist())
    return names


class LayoutSwipes:
    def __init__(self, data_dir: Path, specs: list[str], layouts: dict[str, Layout], numbers: dict[str, int],
                 device: torch.device):
        """`layouts` holds every layout the swipes name; `numbers` gains a number for each new one."""
        frames = output_frames(POINTS)
        xy, forms, targets, lengths, numbered = [], [], [], [], []
        for spec in specs:
            name, _, times = spec.partition(":")
            data = dict(np.load(data_dir / "prepared" / f"{name}.npz"))
            for layout_name in sorted(set(data["layout"].tolist())):
                numbers.setdefault(layout_name, len(numbers))
            rows = []
            for row, (form, layout_name) in enumerate(zip(data["form"], data["layout"])):
                path = key_path(str(form), layouts[str(layout_name)].key_index)
                if path and ctc_frames_needed(path) <= frames:
                    rows.append((row, path, numbers[str(layout_name)]))
            kept = np.array([row for row, _, _ in rows], dtype=np.int64)
            padded = np.zeros((len(rows), frames), dtype=np.int64)
            for index, (_, path, _) in enumerate(rows):
                padded[index, :len(path)] = np.array(path) + 1
            for _ in range(int(times or 1)):
                xy.append(data["xy"][kept])
                forms.append(data["form"][kept])
                targets.append(padded)
                lengths.append(np.array([len(path) for _, path, _ in rows], dtype=np.int64))
                numbered.append(np.array([number for _, _, number in rows], dtype=np.int64))
            print(f"{spec}: {len(rows)} of {len(data['form'])} swipes", flush=True)
        self.forms = np.concatenate(forms)
        self.xy = torch.from_numpy(np.concatenate(xy)).to(device)
        self.targets = torch.from_numpy(np.concatenate(targets)).to(device)
        self.lengths = torch.from_numpy(np.concatenate(lengths)).to(device)
        self.layouts = torch.from_numpy(np.concatenate(numbered)).to(device)

    def batches(self, size: int, generator: torch.Generator | None, rows: torch.Tensor | None = None
                ) -> list[torch.Tensor]:
        """Index batches of one layout each, of `rows` (every swipe when None); shuffled, and only
        full batches, when `generator` is given."""
        layouts = self.layouts.cpu()
        chosen = torch.arange(len(layouts)) if rows is None else rows.cpu()
        found = []
        for number in sorted(set(layouts[chosen].tolist())):
            members = chosen[layouts[chosen] == number]
            if generator is not None:
                members = members[torch.randperm(len(members), generator=generator)]
            found += [members[start:start + size] for start in range(0, len(members), size)
                      if generator is None or start + size <= len(members)]
        if generator is not None:
            found = [found[index] for index in torch.randperm(len(found), generator=generator).tolist()]
        return [batch.to(self.xy.device) for batch in found]
