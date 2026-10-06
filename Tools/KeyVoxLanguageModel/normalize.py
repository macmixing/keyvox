"""Splits raw text into the word sequences the keyboard's context sees.

Matches the keyboard: words are runs of letters with inner apostrophes, lowercased;
sentences end at a period, question mark, exclamation mark, or line break; digits and
other punctuation are skipped without ending the sentence. Bracketed transcript tags
such as "[Music]" are dropped.
"""

import re
from collections.abc import Iterator

_BRACKETED = re.compile(r"\[[^\]]*\]")
_SENTENCE_END = re.compile(r"[.!?\n]+")
_WORD = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)*")


def sentences(text: str) -> Iterator[list[str]]:
    text = _BRACKETED.sub(" ", text).replace("’", "'")
    for sentence in _SENTENCE_END.split(text):
        words = _WORD.findall(sentence.lower())
        if words:
            yield words
