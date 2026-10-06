"""Writes the KeyVox context model from the counts, keeping the entries that matter most
within a fixed size.

The format (little-endian) is the one KeyVoxPredictiveNative's ContextArtifact reads:
"KVLM0002", the total word count (u64), then the number of words, pairs, and sequences
(u32 each), then the three tables, each sorted by its 64-bit FNV-1a key:

    word:     key (u64), log(1 + count) over [0, 16] (u8)
    pair:     key (u64), log(1 + count) over [0, 16] (u8), log P(word | previous) over [-16, 0] (u8)
    sequence: key (u64), log(1 + count) over [0, 16] (u8), log P(word | older, previous) over [-16, 0] (u8)

A word's key hashes its lowercased UTF-8 text; a pair hashes previous, 0xFF, word; a
sequence hashes older, 0xFE, previous, 0xFF, word. A sentence start appears as the
previous or older word `<s>`, so the model knows which words open sentences.

Counts are scaled so they total `--scaled-total`, the size of the text the bundled
rankers were trained against, so their count features stay in range; probabilities come
from the unscaled counts. When the keyboard finds no entry for a pair or sequence it
backs off to the shorter context times 0.4, so entries are kept in order of how much
they correct that estimate: count times the log ratio of the entry's probability to the
backoff estimate.
"""

import argparse
import math
import struct
from pathlib import Path

import numpy as np

from normalize import SENTENCE_START

ID_BITS = 21
ID_MASK = np.uint64((1 << ID_BITS) - 1)
BACKOFF = math.log(0.4)
FNV_OFFSET = 14695981039346656037
FNV_PRIME = 1099511628211
MASK_64 = (1 << 64) - 1


def fnv1a64(*parts: bytes) -> int:
    value = FNV_OFFSET
    for part in parts:
        for byte in part:
            value = ((value ^ byte) * FNV_PRIME) & MASK_64
    return value


def quantized(values: np.ndarray, low: float, high: float) -> np.ndarray:
    return np.clip(np.rint((values - low) / (high - low) * 255), 0, 255).astype(np.uint8)


def strongest(weights: np.ndarray, limit: int) -> np.ndarray:
    """Indices of the `limit` largest positive weights."""
    positive = np.flatnonzero(weights > 0)
    if len(positive) > limit:
        positive = positive[np.argpartition(weights[positive], -limit)[-limit:]]
    return np.sort(positive)


def table(keys: list[int], columns: list[np.ndarray]) -> list[tuple]:
    """Rows sorted by key, keeping the first row of any colliding key."""
    rows = sorted(zip(keys, *columns), key=lambda row: row[0])
    unique = [rows[0]] if rows else []
    for row in rows[1:]:
        if row[0] != unique[-1][0]:
            unique.append(row)
    return unique


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--words", type=int, default=107_000)
    parser.add_argument("--pairs", type=int, default=800_000)
    parser.add_argument("--sequences", type=int, default=600_000)
    parser.add_argument("--scaled-total", type=int, default=31_167_351)
    arguments = parser.parse_args()

    counts = np.load(arguments.data_dir / "counts.npz")
    vocabulary = (arguments.data_dir / "vocabulary.txt").read_text(encoding="utf-8").split("\n")[:-1]
    encoded = [word.encode("utf-8") for word in vocabulary]
    total = int(counts["total_tokens"])
    word_counts = counts["word_counts"].astype(np.float64)
    log_word = np.log(word_counts / total)
    scale = arguments.scaled_total / total

    pair_keys = counts["pair_keys"]
    pair_counts = counts["pair_counts"].astype(np.float64)
    pair_previous = (pair_keys >> np.uint64(ID_BITS)).astype(np.int64)
    pair_word = (pair_keys & ID_MASK).astype(np.int64)
    pair_history = np.bincount(pair_previous, weights=pair_counts, minlength=len(vocabulary))
    log_pair = np.log(pair_counts / pair_history[pair_previous])
    kept_pairs = strongest(pair_counts * (log_pair - (log_word[pair_word] + BACKOFF)), arguments.pairs)

    triple_keys = counts["triple_keys"]
    triple_counts = counts["triple_counts"].astype(np.float64)
    contexts, context_index = np.unique(triple_keys >> np.uint64(ID_BITS), return_inverse=True)
    log_triple = np.log(triple_counts / np.bincount(context_index, weights=triple_counts)[context_index])
    triple_word = (triple_keys & ID_MASK).astype(np.int64)
    triple_pair_keys = triple_keys & np.uint64((1 << (2 * ID_BITS)) - 1)
    kept_pair_keys = pair_keys[kept_pairs]
    position = np.minimum(np.searchsorted(kept_pair_keys, triple_pair_keys), len(kept_pair_keys) - 1)
    pair_is_kept = kept_pair_keys[position] == triple_pair_keys
    shorter = np.where(pair_is_kept, log_pair[kept_pairs][position], log_word[triple_word] + BACKOFF)
    kept_triples = strongest(triple_counts * (log_triple - (shorter + BACKOFF)), arguments.sequences)

    kept_words = np.array(
        [index for index, word in enumerate(vocabulary[:arguments.words + 1]) if word != SENTENCE_START][:arguments.words],
        dtype=np.int64,
    )
    words = table(
        [fnv1a64(encoded[index]) for index in kept_words],
        [quantized(np.log1p(word_counts[kept_words] * scale), 0, 16)],
    )
    pairs = table(
        [
            fnv1a64(encoded[pair_previous[index]], b"\xff", encoded[pair_word[index]])
            for index in kept_pairs
        ],
        [
            quantized(np.log1p(pair_counts[kept_pairs] * scale), 0, 16),
            quantized(log_pair[kept_pairs], -16, 0),
        ],
    )
    triple_older = (triple_keys >> np.uint64(2 * ID_BITS)).astype(np.int64)
    triple_previous = ((triple_keys >> np.uint64(ID_BITS)) & ID_MASK).astype(np.int64)
    triples = table(
        [
            fnv1a64(
                encoded[triple_older[index]], b"\xfe",
                encoded[triple_previous[index]], b"\xff",
                encoded[triple_word[index]],
            )
            for index in kept_triples
        ],
        [
            quantized(np.log1p(triple_counts[kept_triples] * scale), 0, 16),
            quantized(log_triple[kept_triples], -16, 0),
        ],
    )

    with open(arguments.output, "wb") as output:
        output.write(b"KVLM0002")
        output.write(struct.pack("<QIII", arguments.scaled_total, len(words), len(pairs), len(triples)))
        for key, count in words:
            output.write(struct.pack("<QB", key, count))
        for rows in (pairs, triples):
            for key, count, probability in rows:
                output.write(struct.pack("<QBB", key, count, probability))
    print(
        f"wrote {len(words)} words, {len(pairs)} pairs, {len(triples)} sequences "
        f"({arguments.output.stat().st_size} bytes) from {total} words of text"
    )


if __name__ == "__main__":
    main()
