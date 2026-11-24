"""Runs `beam_search.c` over many swipes' emissions, in parallel threads.

The C file is compiled on first use into `<data-dir>/build/`."""

import ctypes
import subprocess
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from os import cpu_count
from pathlib import Path

import numpy as np

from lexicon import KeyTrie

_SOURCE = Path(__file__).with_name("beam_search.c")
_ENTRY_FLOATS = 4  # node, blank, key, score: one int and three floats


@dataclass(frozen=True)
class Pruning:
    beam: int = 100
    gamma: float = 0.186
    beta: float = 1.139


@dataclass(frozen=True)
class Candidates:
    """Per swipe i, candidates `start[i]:start[i + 1]` of `form` / `log_probability`."""

    start: np.ndarray  # [N + 1] int64
    form: np.ndarray  # [C] int32, lexicon form index
    log_probability: np.ndarray  # [C] float32


def _library(data_dir: Path) -> ctypes.CDLL:
    build = data_dir / "build"
    build.mkdir(exist_ok=True)
    library = build / "libkeyvox_beam_search.dylib"
    if not library.exists() or library.stat().st_mtime < _SOURCE.stat().st_mtime:
        subprocess.run(["cc", "-O3", "-shared", "-fPIC", "-o", str(library), str(_SOURCE)], check=True)
    loaded = ctypes.CDLL(str(library))
    loaded.keyvox_beam_search.restype = ctypes.c_int
    return loaded


def _pointer(array: np.ndarray):
    return array.ctypes.data_as(ctypes.c_void_p)


def beam_search(data_dir: Path, emissions: np.ndarray, trie: KeyTrie, pruning: Pruning) -> Candidates:
    """emissions: [N, frames, symbols] float32 log-probabilities, blank at symbol 0."""
    library = _library(data_dir)
    emissions = np.ascontiguousarray(emissions, dtype=np.float32)
    count, frames, symbols = emissions.shape
    arrays = [np.ascontiguousarray(a, dtype=np.int32) for a in
              (trie.node_key, trie.node_depth, trie.child_start, trie.child_node, trie.form_start)]
    widest = int(np.diff(trie.child_start).max()) + 1
    capacity = pruning.beam * widest
    nodes = np.full((count, pruning.beam), -1, dtype=np.int32)
    log_probability = np.zeros((count, pruning.beam), dtype=np.float32)
    found = np.zeros(count, dtype=np.int64)

    def run(chunk: range) -> None:
        slot = np.full(len(trie.node_key), -1, dtype=np.int32)
        current = np.zeros(capacity * _ENTRY_FLOATS, dtype=np.float32)
        following = np.zeros(capacity * _ENTRY_FLOATS, dtype=np.float32)
        for index in chunk:
            found[index] = library.keyvox_beam_search(
                _pointer(emissions[index]), frames, symbols, *(_pointer(a) for a in arrays),
                pruning.beam, ctypes.c_float(pruning.gamma), ctypes.c_float(pruning.beta),
                _pointer(slot), _pointer(current), _pointer(following),
                _pointer(nodes[index]), _pointer(log_probability[index]),
            )

    workers = max(1, (cpu_count() or 1) - 2)  # leaves two cores free
    size = (count + workers - 1) // workers
    with ThreadPoolExecutor(workers) as pool:
        list(pool.map(run, [range(start, min(count, start + size)) for start in range(0, count, size)]))

    kept = np.arange(pruning.beam)[None, :] < found[:, None]
    flat_nodes = nodes[kept]
    flat_scores = log_probability[kept]
    endings = trie.form_start[flat_nodes + 1] - trie.form_start[flat_nodes]
    first = np.repeat(trie.form_start[flat_nodes], endings)
    within = np.arange(endings.sum()) - np.repeat(np.cumsum(endings) - endings, endings)
    per_swipe = np.bincount(np.repeat(np.arange(count), found), weights=endings, minlength=count).astype(np.int64)
    return Candidates(
        start=np.concatenate([[0], np.cumsum(per_swipe)]).astype(np.int64),
        form=trie.form_index[first + within].astype(np.int32),
        log_probability=np.repeat(flat_scores, endings).astype(np.float32),
    )


def save_candidates(path: Path, candidates: Candidates, pruning: Pruning) -> None:
    np.savez(path, start=candidates.start, form=candidates.form, log_probability=candidates.log_probability,
             beam=pruning.beam, gamma=pruning.gamma, beta=pruning.beta)


def load_candidates(path: Path) -> tuple[Candidates, Pruning]:
    data = np.load(path)
    pruning = Pruning(beam=int(data["beam"]), gamma=float(data["gamma"]), beta=float(data["beta"]))
    return Candidates(start=data["start"], form=data["form"], log_probability=data["log_probability"]), pruning
