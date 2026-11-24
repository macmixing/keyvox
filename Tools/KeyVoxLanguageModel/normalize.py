"""Splits raw text into the word sequences the keyboard's context sees.

Matches the keyboard: words are runs of letters with inner apostrophes, lowercased;
sentences end at a period, question mark, exclamation mark, or line break; digits and
other punctuation are skipped without ending the sentence. Bracketed transcript tags
such as "[Music]" are dropped.

A language's `TextRules` add what its writing needs beyond that: composing letters with
their accents (Unicode NFC), so a letter typed as a base letter and a combining accent
stays one letter; marks that open a sentence, such as Spanish "¿" and "¡", which begin a
new sentence without being part of a word; and its quotation marks, where a quotation can
begin. The default rules are the ones the bundled English data was built with.
"""

import html
import re
import unicodedata
from collections.abc import Iterator
from dataclasses import dataclass
from functools import cache

# Stands for the start of a sentence in the model's pairs and sequences; it must match
# `ContextLanguageScorer.sentenceStart` in KeyVoxPredictiveKeyboard.
SENTENCE_START = "<s>"
LINE_BREAK = "\n"

_BRACKETED = re.compile(r"\[[^\]]*\]")
_WORD = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)*")


@dataclass(frozen=True)
class TextRules:
    # Compose each letter with its accents (NFC) before reading words.
    composed: bool = False
    # Marks that begin a new sentence where they stand, such as "¿".
    sentence_opening_marks: str = ""
    # Quotation marks beyond the shared ones, where a quotation can begin.
    quotation_marks: str = ""


DEFAULT_RULES = TextRules()


@dataclass(frozen=True)
class _Patterns:
    sentence_end: re.Pattern
    # Where a sentence or a quotation can begin, so the word after it may be capitalized for
    # that reason alone.
    possible_start: re.Pattern
    # Where a sentence ends for the sentence-opener counts: a run of periods, question marks,
    # or exclamation marks followed by a space or the end of the text, so "example.com" and
    # "3.5" do not end one, or a line break; or where a mark opens the next sentence.
    ending: re.Pattern


@cache
def _patterns(rules: TextRules) -> _Patterns:
    opening = re.escape(rules.sentence_opening_marks)
    quotation = re.escape(rules.quotation_marks)
    ending = r"[.!?]+(?=\s|$)|\n+"
    if opening:
        ending += f"|[{opening}]+"
    return _Patterns(
        sentence_end=re.compile(f"[.!?\\n{opening}]+"),
        possible_start=re.compile(f"[.!?\\n\"“”:(\\[{{{opening}{quotation}]+"),
        ending=re.compile(ending),
    )


def _prepared(text: str, rules: TextRules) -> str:
    if rules.composed:
        text = unicodedata.normalize("NFC", text)
    return _BRACKETED.sub(" ", text).replace("’", "'")


def is_word(text: str) -> bool:
    """Whether `text`, as written, is one word the keyboard reads."""
    return _WORD.fullmatch(text) is not None


def sentences(text: str, rules: TextRules = DEFAULT_RULES) -> Iterator[list[str]]:
    text = _prepared(text, rules)
    for sentence in _patterns(rules).sentence_end.split(text):
        words = _WORD.findall(sentence.lower())
        if words:
            yield words


def sentences_with_endings(text: str, rules: TextRules = DEFAULT_RULES) -> Iterator[tuple[list[str], str | None]]:
    """Each sentence's words with what ended it: ".", "?", "!", LINE_BREAK, or None when the
    text runs out first or a mark opens the next sentence. Three or more periods are an
    ellipsis, which pauses a sentence rather than ending it, as on the keyboard. HTML entities
    such as "&nbsp;" are decoded."""
    if rules.composed:
        text = unicodedata.normalize("NFC", text)
    text = html.unescape(_BRACKETED.sub(" ", text)).replace("’", "'")
    opening = set(rules.sentence_opening_marks)
    words: list[str] = []
    position = 0
    for ending in _patterns(rules).ending.finditer(text):
        words += _WORD.findall(text[position:ending.start()].lower())
        position = ending.end()
        mark = ending.group()
        if mark.startswith(LINE_BREAK):
            mark = LINE_BREAK
        elif set(mark) == {"."} and len(mark) >= 3:
            continue
        elif mark[0] in opening:
            mark = None
        else:
            mark = mark[-1]
        if words:
            yield words, mark
        words = []
    words += _WORD.findall(text[position:].lower())
    if words:
        yield words, None


def written_runs(text: str, rules: TextRules = DEFAULT_RULES) -> Iterator[list[str]]:
    """Words as written, in runs that each begin where a sentence or quotation can begin,
    so a word after the first of a run is capitalized, or not, for its own sake."""
    text = _prepared(text, rules)
    for run in _patterns(rules).possible_start.split(text):
        words = _WORD.findall(run)
        if words:
            yield words
