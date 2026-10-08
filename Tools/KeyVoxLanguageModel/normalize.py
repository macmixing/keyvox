"""Splits raw text into the word sequences the keyboard's context sees.

Matches the keyboard: words are runs of letters with inner apostrophes, lowercased;
sentences end at a period, question mark, exclamation mark, or line break; digits and
other punctuation are skipped without ending the sentence. Bracketed transcript tags
such as "[Music]" are dropped.
"""

import html
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
# Where a sentence ends for the sentence-opener counts: a run of periods, question marks, or
# exclamation marks followed by a space or the end of the text, so "example.com" and "3.5"
# do not end one, or a line break.
_ENDING = re.compile(r"[.!?]+(?=\s|$)|\n+")
LINE_BREAK = "\n"


def sentences(text: str) -> Iterator[list[str]]:
    text = _BRACKETED.sub(" ", text).replace("’", "'")
    for sentence in _SENTENCE_END.split(text):
        words = _WORD.findall(sentence.lower())
        if words:
            yield words


def sentences_with_endings(text: str) -> Iterator[tuple[list[str], str | None]]:
    """Each sentence's words with what ended it: ".", "?", "!", LINE_BREAK, or None when the
    text runs out first. Three or more periods are an ellipsis, which pauses a sentence
    rather than ending it, as on the keyboard. HTML entities such as "&nbsp;" are decoded."""
    text = html.unescape(_BRACKETED.sub(" ", text)).replace("’", "'")
    words: list[str] = []
    position = 0
    for ending in _ENDING.finditer(text):
        words += _WORD.findall(text[position:ending.start()].lower())
        position = ending.end()
        mark = ending.group()
        if mark.startswith(LINE_BREAK):
            mark = LINE_BREAK
        elif set(mark) == {"."} and len(mark) >= 3:
            continue
        else:
            mark = mark[-1]
        if words:
            yield words, mark
        words = []
    words += _WORD.findall(text[position:].lower())
    if words:
        yield words, None


def written_runs(text: str) -> Iterator[list[str]]:
    """Words as written, in runs that each begin where a sentence or quotation can begin,
    so a word after the first of a run is capitalized, or not, for its own sake."""
    text = _BRACKETED.sub(" ", text).replace("’", "'")
    for run in _POSSIBLE_START.split(text):
        words = _WORD.findall(run)
        if words:
            yield words
