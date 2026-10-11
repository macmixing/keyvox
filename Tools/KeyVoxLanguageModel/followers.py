"""Shared by the builders of follower lists (write_unknown_word_followers.py,
write_word_followers.py): grouping counts, how written sentences end and begin, and writing a
context's followers with the sentence starts transcripts bring in taken off.

Transcripts mark no sentence ends, so there a word that ends a sentence is followed by the next
sentence's first word. The written sources, which do mark them, tell how often a word ends a
sentence and which words start one; that many sentence starts are taken off a context's counts.
"""

import math
from collections import Counter
from pathlib import Path

import numpy as np


def grouped(keys: np.ndarray, counts: np.ndarray):
    unique, inverse = np.unique(keys, return_inverse=True)
    return unique, np.bincount(inverse, weights=counts)


def written_sentence_ends(paths: list[Path]) -> tuple[Counter, Counter, Counter]:
    """How often each word appears in the written sentences, ends one, and starts one."""
    uses: Counter = Counter()
    endings: Counter = Counter()
    openers: Counter = Counter()
    for path in paths:
        with open(path, encoding="utf-8") as sentences:
            for sentence in sentences:
                words = sentence.split()
                if not words:
                    continue
                uses.update(words)
                endings[words[-1]] += 1
                openers[words[0]] += 1
    return uses, endings, openers


def followers_line(context: str, follower_ids: np.ndarray, follower_counts: np.ndarray, total: float,
                   opener_shares: np.ndarray, ending_share: float, vocabulary: list[str], limit: int) -> str:
    """Followers after taking off the sentence starts `total` uses would bring in transcripts."""
    adjusted = follower_counts - ending_share * total * opener_shares[follower_ids]
    kept_total = total * (1 - ending_share)
    order = [index for index in np.argsort(-adjusted, kind="stable") if adjusted[index] > 0][:limit]
    pairs = " ".join(f"{vocabulary[follower_ids[index]]}:{math.log(adjusted[index] / kept_total):.3f}" for index in order)
    return f"{context}\t{pairs}\n"
