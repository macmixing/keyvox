"""Counts words, word pairs, and three-word sequences across the extracted sentences.

Writes `<data_dir>/vocabulary.txt` (one word per line; a word's line number is its id)
and `<data_dir>/counts.npz`. Pairs and sequences are packed into one key of 21 bits per
word id. Every sentence begins with the sentence-start marker, the vocabulary's last id,
so the words that open sentences are counted after it. Words counted only once, or beyond
the vocabulary limit, are counted on their own but break pairs and sequences as a
sentence end does. Each source's sentences count as many times as the language's count
weights give it (languages.py, once unless listed), and `counts.npz` records the weights
(`source_names`, `source_weights`) so a step that takes sentences out of the counts takes
them out as many times.
"""

import argparse
from array import array
from collections import Counter
from collections.abc import Iterator
from pathlib import Path

import numpy as np

from languages import LANGUAGES, language_argument
from normalize import SENTENCE_START

ID_BITS = 21
MAXIMUM_VOCABULARY = (1 << ID_BITS) - 1
CHUNK_TOKENS = 50_000_000
BREAK = -1


def sentence_words(path: Path) -> Iterator[list[str]]:
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
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    paths = sorted((arguments.data_dir / "sentences").glob("*.txt"))
    weights = {path: LANGUAGES[arguments.language].count_weights.get(path.stem, 1) for path in paths}

    word_counts: Counter[str] = Counter()
    sentence_count = 0
    for path in paths:
        source_counts: Counter[str] = Counter()
        source_sentences = 0
        for words in sentence_words(path):
            source_counts.update(words)
            source_sentences += 1
        for word, count in source_counts.items():
            word_counts[word] += count * weights[path]
        sentence_count += source_sentences * weights[path]
    total_tokens = sum(word_counts.values())
    vocabulary = [word for word, count in word_counts.most_common(MAXIMUM_VOCABULARY - 1) if count >= 2]
    ids = {word: index for index, word in enumerate(vocabulary)}
    sentence_start = len(vocabulary)
    vocabulary.append(SENTENCE_START)
    word_counts[SENTENCE_START] = sentence_count
    print(f"{total_tokens} words, {len(word_counts)} distinct, {len(vocabulary)} in vocabulary", flush=True)

    empty = (np.zeros(0, dtype=np.uint64), np.zeros(0, dtype=np.int64))
    pair_keys, pair_counts = empty
    triple_keys, triple_counts = empty
    buffer = array("q")
    processed = 0

    def flush(weight: int) -> None:
        nonlocal pair_keys, pair_counts, triple_keys, triple_counts, buffer
        if len(buffer) < 3:
            buffer = array("q")
            return
        pairs, triples = chunk_ngrams(np.frombuffer(buffer, dtype=np.int64))
        unique, counts = np.unique(pairs, return_counts=True)
        pair_keys, pair_counts = merged(pair_keys, pair_counts, unique, counts * weight)
        unique, counts = np.unique(triples, return_counts=True)
        triple_keys, triple_counts = merged(triple_keys, triple_counts, unique, counts * weight)
        buffer = array("q")

    for path in paths:
        for words in sentence_words(path):
            buffer.append(sentence_start)
            buffer.extend([ids.get(word, BREAK) for word in words])
            buffer.append(BREAK)
            processed += len(words)
            if len(buffer) >= CHUNK_TOKENS:
                flush(weights[path])
                print(f"  counted {processed} words: {len(pair_keys)} pairs, {len(triple_keys)} sequences", flush=True)
        flush(weights[path])

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
        source_names=np.array([path.stem for path in paths]),
        source_weights=np.array([weights[path] for path in paths], dtype=np.int64),
    )
    print(f"{len(pair_keys)} pairs, {len(triple_keys)} sequences", flush=True)


if __name__ == "__main__":
    main()
