"""Writes the grammar words: the determiners, pronouns, prepositions, conjunctions, and particles
among the most common words, which every sentence repeats ("the", "and", "of"), one per line.
The suggestion bar lets them come back while it keeps from offering a word the user already
picked from it in a row (PredictiveTypingSession).

Each word's lexical class comes from tag_word_kinds.swift (`<data-dir>/word_kinds.tsv`), and how
common it is from count_ngrams.py (`<data-dir>/vocabulary.txt`, most common first). The tagger
reads common words reliably; past the most common few thousand it starts calling rare words such
as names pronouns, so only the most common words (`--most-common`) are kept.
"""

import argparse
from pathlib import Path

GRAMMAR_CLASSES = {"Determiner", "Pronoun", "Preposition", "Conjunction", "Particle"}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--most-common", type=int, default=2000, help="most common words a grammar word is among")
    arguments = parser.parse_args()

    common = set((arguments.data_dir / "vocabulary.txt").read_text(encoding="utf-8").splitlines()[:arguments.most_common])
    words = sorted(
        word for word, kind in (line.split("\t") for line in (arguments.data_dir / "word_kinds.tsv").read_text(encoding="utf-8").splitlines())
        if kind in GRAMMAR_CLASSES and word in common
    )
    arguments.output.write_text("".join(word + "\n" for word in words), encoding="utf-8")
    print(f"{len(words)} grammar words")


if __name__ == "__main__":
    main()
