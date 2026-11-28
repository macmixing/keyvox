"""Writes swipes of a typing language's words made from recorded English swipes, for fine-tuning an
encoder on the language (`rank_layouts.py --language`): `prepared/<output>-train.npz` and
`<output>-val.npz`, with `xy`, `form`, `word`, and `layout`.

Each swipe's word is drawn by how often the language's texts write it on its own (`counts`, the
word counts `Tools/KeyVoxLanguageModel/count_swipe_words.py` writes), among the words `lexicon`
holds; its layout is drawn from `--layouts`, the keyboard's letter layouts. The word's form is as
the language's swipe model reads it on that layout (`words.swipe_letters`): a letter the layout
has no key for is folded onto its base letter, as the keyboard swipes it there. Of `--donors` English
swipes drawn from the split (`prepared/train.npz` and `extra.npz`, or `val.npz`) whose key path on
swipe.futo.org's QWERTY is as long as the word's, the one whose keys lie nearest the word's keys,
by their mean distance, is moved so each of its keys goes to the word's key in the same place
(`layout_warp.warp`), keeping the person's path around the keys.
Words whose key path is longer than any English swipe's are left out.

    python retarget_swipes.py <data-dir> de-words <swipe_word_counts.tsv> <unigrams.tsv> --language de \\
        --layouts QWERTZ-German,QWERTZ,QWERTY --swipes 400000"""

import argparse
from collections import defaultdict
from multiprocessing import Pool
from os import cpu_count
from pathlib import Path

import numpy as np

from layout_warp import warp
from layouts import load_layout, load_letter_layout
from lexicon import load_lexicon
from prepare_swipes import POINTS
from train import output_frames
from words import ctc_frames_needed, key_path, letter_form, swipe_letters

SOURCE_LAYOUT = "qwerty"
SPLITS = {"train": ("train.npz", "extra.npz"), "val": ("val.npz",)}
# A twentieth as many validation swipes as training swipes.
VALIDATION_SHARE = 20
WORKERS = max(1, (cpu_count() or 1) - 2)

_source = None
_targets = None


def _start(data_dir: Path, names: list[str]) -> None:
    global _source, _targets
    _source = load_layout(data_dir, SOURCE_LAYOUT)
    _targets = {name: load_letter_layout(name) for name in names}


def _warp(job: tuple[np.ndarray, str, str, str]) -> np.ndarray:
    xy, source_letters, name, target_letters = job
    return warp(xy, source_letters, _source, _targets[name], target_letters)


def read_counts(path: Path) -> dict[str, int]:
    """How often the texts write each word on its own, from count_swipe_words.py's table: a
    word, then each source's count and joined count, then two capitals columns."""
    counts: dict[str, int] = {}
    with open(path, encoding="utf-8") as rows:
        rows.readline()
        for row in rows:
            fields = row.rstrip("\n").split("\t")
            numbers = [int(value) for value in fields[1:-2]]
            counts[fields[0]] = counts.get(fields[0], 0) + sum(numbers[0::2]) - sum(numbers[1::2])
    return counts


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("output")
    parser.add_argument("counts", type=Path)
    parser.add_argument("lexicon", type=Path, help="the language's unigram list, as evaluate.py reads it")
    parser.add_argument("--language", required=True)
    parser.add_argument("--layouts", required=True, help="comma-separated letter layout names")
    parser.add_argument("--swipes", type=int, required=True, help="training swipes to write")
    parser.add_argument("--donors", type=int, default=1, help="English swipes to choose the nearest of")
    parser.add_argument("--seed", type=int, default=0)
    arguments = parser.parse_args()
    names = arguments.layouts.split(",")
    letters, spellings = swipe_letters(arguments.language)
    source = load_layout(arguments.data_dir, SOURCE_LAYOUT)
    frames = output_frames(POINTS)

    # Each layout's key letters, the words its lexicon holds, and each word's key path there.
    layouts = {name: load_letter_layout(name) for name in names}
    keys = {name: "".join(letter for letter in letters if letter in layouts[name].key_index) for name in names}
    lexicon_forms = {name: set(load_lexicon(arguments.lexicon, keys[name], spellings).forms) for name in names}
    counts = read_counts(arguments.counts)
    words, weights = [], []
    for word, count in counts.items():
        if count > 0 and all(letter_form(word, keys[name], spellings) in lexicon_forms[name] for name in names):
            words.append(word)
            weights.append(count)
    weights = np.array(weights, dtype=np.float64) / sum(weights)
    print(f"{len(words)} words of {len(counts)} drawn from", flush=True)

    generator = np.random.default_rng(arguments.seed)
    prepared = arguments.data_dir / "prepared"
    with Pool(WORKERS, initializer=_start, initargs=(arguments.data_dir, names)) as pool:
        for split, files in SPLITS.items():
            data = [np.load(prepared / name) for name in files]
            xy = np.concatenate([item["xy"] for item in data])
            forms = np.concatenate([item["form"] for item in data])
            by_length: dict[int, list[tuple[int, str]]] = defaultdict(list)
            for row, form in enumerate(forms):
                path = key_path(str(form), source.key_index)
                if path:
                    by_length[len(path)].append((row, "".join(source.letters[key] for key in path)))
            # Each English swipe's key centers, by key-path length, to find the nearest donor.
            donor_centers = {length: np.stack([source.centers[[source.key_index[letter] for letter in letters]]
                                               for _, letters in donors])
                             for length, donors in by_length.items()}
            wanted = arguments.swipes if split == "train" else arguments.swipes // VALIDATION_SHARE
            jobs, kept_words, kept_forms, kept_layouts = [], [], [], []
            while len(jobs) < wanted:
                drawn = generator.choice(len(words), size=wanted, p=weights)
                for number, word in zip(generator.integers(len(names), size=wanted), (words[index] for index in drawn)):
                    if len(jobs) == wanted:
                        break
                    name = names[number]
                    form = letter_form(word, keys[name], spellings)
                    path = key_path(form, layouts[name].key_index)
                    if not path or ctc_frames_needed(path) > frames or not by_length.get(len(path)):
                        continue
                    donors = by_length[len(path)]
                    choices = generator.integers(len(donors), size=arguments.donors)
                    target_centers = layouts[name].centers[path]
                    distance = np.linalg.norm(donor_centers[len(path)][choices] - target_centers, axis=2).mean(axis=1)
                    row, source_letters = donors[choices[int(np.argmin(distance))]]
                    jobs.append((xy[row], source_letters, name, "".join(layouts[name].letters[key] for key in path)))
                    kept_words.append(word)
                    kept_forms.append(form)
                    kept_layouts.append(name)
            moved = pool.map(_warp, jobs, chunksize=2048)
            np.savez(
                prepared / f"{arguments.output}-{split}.npz",
                xy=np.stack(moved), form=np.array(kept_forms), word=np.array(kept_words), layout=np.array(kept_layouts),
            )
            print(f"wrote {arguments.output}-{split}.npz: {len(jobs)} swipes, "
                  + ", ".join(f"{name} {kept_layouts.count(name)}" for name in names), flush=True)


if __name__ == "__main__":
    main()
