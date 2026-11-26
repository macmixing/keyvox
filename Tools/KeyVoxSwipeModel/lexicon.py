"""The words a swipe can decode to, read from KeyVox's bundled English dictionary, and the
key-path trie the beam search walks.

The dictionary is read from the unigram dump of the bundled LatinIME dictionary: one line
per word with its tab-separated spelling, probability (0-255, already log-scaled), four
flag digits (beginning of sentence, not a word, possibly offensive, blacklisted), and
shortcut count. Spellings that share a swipe form (case, accent, or apostrophe variants)
are one entry, keeping the highest probability and the most probable spelling."""

from dataclasses import dataclass
from pathlib import Path

import numpy as np

from layouts import Layout
from words import key_path, letter_form

_NOT_A_WORD_FLAG = 1
_BLACKLISTED_FLAG = 3


@dataclass(frozen=True)
class Lexicon:
    forms: tuple[str, ...]
    spellings: tuple[str, ...]
    frequency: np.ndarray  # [F] float32


def load_lexicon(path: Path) -> Lexicon:
    best: dict[str, tuple[int, str]] = {}
    with open(path, encoding="utf-8") as file:
        for line in file:
            spelling, probability, flags, _ = line.rstrip("\n").split("\t")
            if flags[_NOT_A_WORD_FLAG] == "1" or flags[_BLACKLISTED_FLAG] == "1":
                continue
            form = letter_form(spelling)
            if not form:
                continue
            value = int(probability)
            if form not in best or value > best[form][0]:
                best[form] = (value, spelling)
    forms = tuple(sorted(best))
    return Lexicon(
        forms=forms,
        spellings=tuple(best[form][1] for form in forms),
        frequency=np.array([best[form][0] for form in forms], dtype=np.float32),
    )


@dataclass(frozen=True)
class KeyTrie:
    """Nodes are key-path prefixes; node 0 is the empty path. Children and the forms that
    end at a node are stored as compressed rows."""

    node_key: np.ndarray  # [N] int32, -1 for the root
    node_depth: np.ndarray  # [N] int32
    child_start: np.ndarray  # [N + 1] int32
    child_node: np.ndarray  # [C] int32
    form_start: np.ndarray  # [N + 1] int32
    form_index: np.ndarray  # [W] int32
    form_path_length: np.ndarray  # [F] int32, key-path length per lexicon form, 0 if not typeable


def build_trie(lexicon: Lexicon, layout: Layout, keep_doubles: bool = False) -> KeyTrie:
    key_index = layout.key_index
    children: list[dict[int, int]] = [{}]
    keys = [-1]
    depths = [0]
    endings: list[list[int]] = [[]]
    path_lengths = np.zeros(len(lexicon.forms), dtype=np.int32)
    for form_number, form in enumerate(lexicon.forms):
        path = key_path(form, key_index, keep_doubles)
        if not path:
            continue
        path_lengths[form_number] = len(path)
        node = 0
        for key in path:
            child = children[node].get(key)
            if child is None:
                child = len(children)
                children[node][key] = child
                children.append({})
                keys.append(key)
                depths.append(depths[node] + 1)
                endings.append([])
            node = child
        endings[node].append(form_number)

    child_start = np.zeros(len(children) + 1, dtype=np.int32)
    child_node = []
    form_start = np.zeros(len(children) + 1, dtype=np.int32)
    form_index = []
    for node, mapping in enumerate(children):
        child_node.extend(mapping[key] for key in sorted(mapping))
        child_start[node + 1] = len(child_node)
        form_index.extend(endings[node])
        form_start[node + 1] = len(form_index)
    return KeyTrie(
        node_key=np.array(keys, dtype=np.int32),
        node_depth=np.array(depths, dtype=np.int32),
        child_start=child_start,
        child_node=np.array(child_node, dtype=np.int32),
        form_start=form_start,
        form_index=np.array(form_index, dtype=np.int32),
        form_path_length=path_lengths,
    )
