"""Finds the names a source uses: words it writes with a capital in the middle of a
sentence nearly every time, so the capital is the word's own rather than the sentence's.

Two kinds of words are capitalized the same way but are not names: the language's words
always written with capitals and their contractions, from its language.json, and its common
words spelled with a capital, such as German nouns, which the language's lexicon lists
(`capitalized_common_words`)."""

from collections import Counter
from collections.abc import Iterable

from normalize import DEFAULT_RULES, TextRules, written_runs

# A word counts as a name once the source shows it this often, almost always capitalized.
_MINIMUM_OCCURRENCES = 20
_CAPITALIZED_SHARE = 0.9
_APOSTROPHES = "'’"


def is_written_as_name(seen: int, capitalized: int) -> bool:
    """Whether a word written `seen` times in the middle of a sentence, `capitalized` of them
    with a capital, is written as a name."""
    return seen >= _MINIMUM_OCCURRENCES and capitalized / seen >= _CAPITALIZED_SHARE


def is_always_capitalized(word: str, always_capitalized: Iterable[str]) -> bool:
    """The keyboard's rule in WordCasing.writingAlwaysCapitalized, from the always-capitalized
    words in a typing language's language.json: each such word and its contractions."""
    for capitalized in always_capitalized:
        lowered = capitalized.lower()
        if word == lowered or (word.startswith(lowered) and word[len(lowered)] in _APOSTROPHES):
            return True
    return False


def capitalized_names(texts: Iterable[str], rules: TextRules = DEFAULT_RULES,
                      always_capitalized: Iterable[str] = (),
                      capitalized_common_words: frozenset[str] = frozenset()) -> set[str]:
    always_capitalized = tuple(always_capitalized)
    seen: Counter[str] = Counter()
    capitalized: Counter[str] = Counter()
    for text in texts:
        for run in written_runs(text, rules):
            # The first word of a run may be capitalized only for starting it.
            for word in run[1:]:
                lowered = word.lower()
                seen[lowered] += 1
                if word[:1].isupper():
                    capitalized[lowered] += 1
    return {
        word
        for word, count in seen.items()
        if is_written_as_name(count, capitalized[word])
        and not is_always_capitalized(word, always_capitalized)
        and word not in capitalized_common_words
    }


def mentions_any(text: str, names: set[str], rules: TextRules = DEFAULT_RULES) -> bool:
    return any(word.lower() in names for run in written_runs(text, rules) for word in run)
