"""Finds the lexicon words a keyboard word list lacks that the language's text writes as often as
the word list's own words, for a word list that leaves out common words: AOSP's German list, for
one, lacks almost every lowercase word beginning with an umlaut, and common verb forms (see the
README's "Vocabulary").

A lexicon word joins when `count_ngrams.py`'s counts of the language's sentences have it at least
as often as the median word-list word the text writes at all, so a rare lexicon form, which the
word list rightly leaves out, stays out."""

from pathlib import Path
from statistics import median

import numpy as np


def written_lexicon_words(data_dir: Path, word_list: set[str], lexicon: set[str]) -> set[str]:
    """The lexicon's words, in lowercase, that `word_list` (lowercase) lacks and the counts in
    `data_dir` have at least as often as the median word-list word they have."""
    words = (data_dir / "vocabulary.txt").read_text(encoding="utf-8").splitlines()
    counts = np.load(data_dir / "counts.npz")["word_counts"]
    count_of = dict(zip(words, counts.tolist()))
    listed_counts = [count_of[word] for word in word_list if word in count_of]
    if not listed_counts:
        return set()
    least = median(listed_counts)
    lexicon_words = {form.lower() for form in lexicon}
    return {word for word in lexicon_words - word_list if count_of.get(word, 0) >= least}
