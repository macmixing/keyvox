"""Splits raw text into the word sequences the keyboard's context sees.

Matches the keyboard: words are runs of letters with inner apostrophes, lowercased;
sentences end at a period, question mark, exclamation mark, or line break; digits and
other punctuation, Spanish inverted question and exclamation marks among them, are skipped
without ending the sentence. Bracketed transcript tags such as "[Music]" are dropped.

A language's `TextRules` add what its writing needs beyond that: composing letters with
their accents (Unicode NFC), so a letter typed as a base letter and a combining accent
stays one letter; its quotation marks, where a quotation can begin; the mark its keyboard
types as an apostrophe, read as one between letters; and whether a period right after a digit
writes an ordinal number rather than ending the sentence, as the keyboard reads them from the
language's language.json. The default rules are the
ones the bundled English data was built with.
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
_SENTENCE_END = re.compile(r"[.!?\n]+")
_WORD = re.compile(r"[^\W\d_]+(?:'[^\W\d_]+)*")
# Where a sentence ends for the sentence-opener counts: a run of periods, question marks, or
# exclamation marks followed by a space or the end of the text, so "example.com" and "3.5"
# do not end one, or a line break.
_ENDING = re.compile(r"[.!?]+(?=\s|$)|\n+")
_MARKDOWN_CODE = re.compile(r"```.*?(?:```|\Z)|`[^`\n]*`", re.DOTALL)
# A run of text without spaces that holds something other than letters: punctuation, digits,
# or a connector such as "_". A run of letters alone is a single word.
_MIXED_RUN = re.compile(r"\S*(?:[^\w\s]|[\d_])\S*")
_RUN_EDGES = re.compile(r"^\W+|\W+$")


@dataclass(frozen=True)
class TextRules:
    # Compose each letter with its accents (NFC) before reading words.
    composed: bool = False
    # Quotation marks beyond the shared ones, where a quotation can begin.
    quotation_marks: str = ""
    # Marks beyond "'" and "’" written as an apostrophe between two letters.
    apostrophes: str = ""
    # A period right after a digit writes an ordinal number and ends no sentence.
    ordinal_periods: bool = False


DEFAULT_RULES = TextRules()


@cache
def _possible_start(rules: TextRules) -> re.Pattern:
    """Where a sentence or a quotation can begin, so the word after it may be capitalized for
    that reason alone."""
    return re.compile(f"[.!?\\n\"“”:(\\[{{{re.escape(rules.quotation_marks)}]+")


# A period right after a digit that is not part of a run of periods, as an ordinal number ends.
_ORDINAL_PERIOD = re.compile(r"(?<=\d)\.(?!\.)")


@cache
def _apostrophe(rules: TextRules) -> re.Pattern | None:
    """One of the language's other apostrophe marks between two letters."""
    if not rules.apostrophes:
        return None
    return re.compile(f"(?<=[^\\W\\d_])[{re.escape(rules.apostrophes)}](?=[^\\W\\d_])")


def _marks_read(text: str, rules: TextRules) -> str:
    """`text` with its apostrophes written "'" and, where the language writes ordinal numbers
    with a period, those periods taken out, so neither splits a word or a sentence."""
    text = text.replace("’", "'")
    if (apostrophe := _apostrophe(rules)) is not None:
        text = apostrophe.sub("'", text)
    if rules.ordinal_periods:
        text = _ORDINAL_PERIOD.sub(" ", text)
    return text


def _prepared(text: str, rules: TextRules) -> str:
    if rules.composed:
        text = unicodedata.normalize("NFC", text)
    return _marks_read(_BRACKETED.sub(" ", text), rules)


def is_word(text: str) -> bool:
    """Whether `text`, as written, is one word the keyboard reads."""
    return _WORD.fullmatch(text) is not None


def words(text: str) -> list[str]:
    """The words of `text` as the keyboard reads them, lowercased, sentence ends aside."""
    return _WORD.findall(text.lower())


def prose(text: str) -> str:
    """`text` without what is no prose: HTML character references such as "&nbsp;" decoded, as
    `sentences_with_endings` decodes them, Markdown code (fenced blocks and inline spans)
    taken out, and bracketed transcript tags dropped."""
    return _BRACKETED.sub(" ", html.unescape(_MARKDOWN_CODE.sub(" ", text))).replace("’", "'")


def joined_words(text: str) -> list[str]:
    """The words, lowercased, that `text` writes joined to other letters or digits in one run
    without spaces ("https://www", "pre-order", "ipv6", "__init__"); punctuation around a run,
    such as a comma or brackets, does not join."""
    joined: list[str] = []
    for run in _MIXED_RUN.findall(text):
        core = _RUN_EDGES.sub("", run)
        if core and _WORD.fullmatch(core) is None:
            joined += _WORD.findall(core.lower())
    return joined


def sentences(text: str, rules: TextRules = DEFAULT_RULES) -> Iterator[list[str]]:
    text = _prepared(text, rules)
    for sentence in _SENTENCE_END.split(text):
        words = _WORD.findall(sentence.lower())
        if words:
            yield words


def sentences_with_endings(text: str, rules: TextRules = DEFAULT_RULES) -> Iterator[tuple[list[str], str | None]]:
    """Each sentence's words with what ended it: ".", "?", "!", LINE_BREAK, or None when the
    text runs out first. Three or more periods are an
    ellipsis, which pauses a sentence rather than ending it, as on the keyboard. HTML entities
    such as "&nbsp;" are decoded."""
    for words, ending, _ in sentences_with_openings(text, rules):
        yield words, ending


def sentences_with_openings(text: str, rules: TextRules = DEFAULT_RULES,
                            opening_marks: str = "") -> Iterator[tuple[list[str], str | None, str | None]]:
    """`sentences_with_endings`, each sentence also with the one of `opening_marks` it opens
    with, before its first word and after any spaces, or None."""
    if rules.composed:
        text = unicodedata.normalize("NFC", text)
    text = _marks_read(html.unescape(_BRACKETED.sub(" ", text)), rules)
    words: list[str] = []
    position = 0
    start = 0
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
            yield words, mark, _opening(text[start:position], opening_marks)
        words = []
        start = position
    words += _WORD.findall(text[position:].lower())
    if words:
        yield words, None, _opening(text[start:], opening_marks)


def _opening(sentence: str, opening_marks: str) -> str | None:
    lead = sentence.lstrip()
    return lead[0] if lead and lead[0] in opening_marks else None


def begins_written_run(before: str, rules: TextRules = DEFAULT_RULES) -> bool:
    """Whether a word written right after `before` begins a run of `written_runs`: no word
    comes before it since where a sentence or quotation can begin, so it may be capitalized
    for that reason alone."""
    return _WORD.search(_possible_start(rules).split(_prepared(before, rules))[-1]) is None


def written_runs(text: str, rules: TextRules = DEFAULT_RULES) -> Iterator[list[str]]:
    """Words as written, in runs that each begin where a sentence or quotation can begin,
    so a word after the first of a run is capitalized, or not, for its own sake."""
    text = _prepared(text, rules)
    for run in _possible_start(rules).split(text):
        words = _WORD.findall(run)
        if words:
            yield words
