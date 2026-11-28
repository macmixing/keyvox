"""Finds the contractions a language's carefully written sources write as often as the word list's
own words, for a word list that holds none: AOSP's German list, for one, lacks every word joined to
a clitic by an apostrophe, which German writes often and Apple's German keyboard restores when the
apostrophe is left out (see the README's "Vocabulary").

A contraction is a word of the written sources' sentences (`extract_sentences.py`'s
`<data_dir>/sentences/<source>.txt`, lowercase) with an inner apostrophe whose part before it is a
word of the word list. It joins when those sentences write it at least as often as the median
word-list word they write at all, so a rare joining, or a word of another language whose first part
the word list happens to hold, stays out."""

from collections import Counter
from pathlib import Path
from statistics import median


def written_contractions(data_dir: Path, sources: tuple[str, ...], word_list: set[str]) -> set[str]:
    """The contractions, in lowercase, that `sources` write at least as often as the median
    `word_list` (lowercase) word they write."""
    counts: Counter[str] = Counter()
    for source in sources:
        with open(data_dir / "sentences" / f"{source}.txt", encoding="utf-8") as lines:
            for line in lines:
                counts.update(line.split())
    listed_counts = [counts[word] for word in word_list if word in counts]
    if not listed_counts:
        return set()
    least = median(listed_counts)
    return {word for word, count in counts.items()
            if count >= least and "'" in word.strip("'") and word not in word_list
            and word.split("'", 1)[0] in word_list}
