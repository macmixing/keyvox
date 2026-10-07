"""Splits raw text into the word sequences the keyboard's context sees.

Matches the keyboard: words are runs of letters with inner apostrophes, lowercased;
sentences end at a period, question mark, exclamation mark, or line break; digits and
other punctuation are skipped without ending the sentence. Bracketed transcript tags
such as "[Music]" are dropped.
"""

import re
from collections.abc import Iterator

# Stands for the start of a sentence in the model's pairs and sequences; it must match
# `ContextLanguageScorer.sentenceStart` in KeyVoxPredictiveKeyboard.
SENTENCE_START = "<s>"

_BRACKETED = re.compile(r"\[[^\]]*\]")
_SENTENCE_END = re.compile(r"[.!?\n]+")
# Where a sentence or a quotation can begin, so the word after it may be capitalized for
# that reason alone.
_POSSIBLE_START = re.compile(r"[.!?\n\"“”:(\[{]+")
_WORD = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)*")


def sentences(text: str) -> Iterator[list[str]]:
    text = _BRACKETED.sub(" ", text).replace("’", "'")
    for sentence in _SENTENCE_END.split(text):
        words = _WORD.findall(sentence.lower())
        if words:
            yield words


def written_runs(text: str) -> Iterator[list[str]]:
    """Words as written, in runs that each begin where a sentence or quotation can begin,
    so a word after the first of a run is capitalized, or not, for its own sake."""
    text = _BRACKETED.sub(" ", text).replace("’", "'")
    for run in _POSSIBLE_START.split(text):
        words = _WORD.findall(run)
        if words:
            yield words
