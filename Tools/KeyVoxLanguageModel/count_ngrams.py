"""Counts words, word pairs, and three-word sequences across the extracted sentences.

Writes `<data_dir>/vocabulary.txt` (one word per line; a word's line number is its id)
and `<data_dir>/counts.npz`. Pairs and sequences are packed into one key of 21 bits per
word id. Words seen only once, or beyond the vocabulary limit, are counted on their own
but break pairs and sequences as a sentence end does.
"""

import argparse
from array import array
from collections import Counter
from collections.abc import Iterator
from pathlib import Path

import numpy as np

ID_BITS = 21
MAXIMUM_VOCABULARY = (1 << ID_BITS) - 1
CHUNK_TOKENS = 50_000_000
BREAK = -1


def sentence_words(paths: list[Path]) -> Iterator[list[str]]:
    for path in paths:
        with open(path, encoding="utf-8") as lines:
            for line in lines:
                yield line.split()


def merged(keys: np.ndarray, counts: np.ndarray, new_keys: np.ndarray, new_counts: np.ndarray):
    unique, inverse = np.unique(np.concatenate([keys, new_keys]), return_inverse=True)
    totals = np.bincount(inverse, weights=np.concatenate([counts, new_counts]))
    return unique, totals.astype(np.int64)


def chunk_ngrams(ids: np.ndarray):
    """Pair and sequence keys within a run of word ids, never across a break."""
    known = ids >= 0
    words = ids.astype(np.uint64)
    pair = known[:-1] & known[1:]
    pairs = (words[:-1][pair] << np.uint64(ID_BITS)) | words[1:][pair]
    triple = known[:-2] & known[1:-1] & known[2:]
    triples = (
        (words[:-2][triple] << np.uint64(2 * ID_BITS))
        | (words[1:-1][triple] << np.uint64(ID_BITS))
        | words[2:][triple]
    )
    return pairs, triples


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    paths = sorted((arguments.data_dir / "sentences").glob("*.txt"))

    word_counts: Counter[str] = Counter()
    for words in sentence_words(paths):
        word_counts.update(words)
    total_tokens = sum(word_counts.values())
    vocabulary = [word for word, count in word_counts.most_common(MAXIMUM_VOCABULARY) if count >= 2]
    ids = {word: index for index, word in enumerate(vocabulary)}
    print(f"{total_tokens} words, {len(word_counts)} distinct, {len(vocabulary)} in vocabulary", flush=True)

    empty = (np.zeros(0, dtype=np.uint64), np.zeros(0, dtype=np.int64))
    pair_keys, pair_counts = empty
    triple_keys, triple_counts = empty
    buffer = array("q")
    processed = 0

    def flush() -> None:
        nonlocal pair_keys, pair_counts, triple_keys, triple_counts, buffer
        if len(buffer) < 3:
            buffer = array("q")
            return
        pairs, triples = chunk_ngrams(np.frombuffer(buffer, dtype=np.int64))
        unique, counts = np.unique(pairs, return_counts=True)
        pair_keys, pair_counts = merged(pair_keys, pair_counts, unique, counts)
        unique, counts = np.unique(triples, return_counts=True)
        triple_keys, triple_counts = merged(triple_keys, triple_counts, unique, counts)
        buffer = array("q")

    for words in sentence_words(paths):
        buffer.extend([ids.get(word, BREAK) for word in words])
        buffer.append(BREAK)
        processed += len(words)
        if len(buffer) >= CHUNK_TOKENS:
            flush()
            print(f"  counted {processed} words: {len(pair_keys)} pairs, {len(triple_keys)} sequences", flush=True)
    flush()

    with open(arguments.data_dir / "vocabulary.txt", "w", encoding="utf-8") as output:
        output.writelines(word + "\n" for word in vocabulary)
    np.savez(
        arguments.data_dir / "counts.npz",
        total_tokens=np.int64(total_tokens),
        word_counts=np.array([word_counts[word] for word in vocabulary], dtype=np.int64),
        pair_keys=pair_keys,
        pair_counts=pair_counts,
        triple_keys=triple_keys,
        triple_counts=triple_counts,
    )
    print(f"{len(pair_keys)} pairs, {len(triple_keys)} sequences", flush=True)


if __name__ == "__main__":
    main()
