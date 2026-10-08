"""Finds the names a source uses: words it writes with a capital in the middle of a
sentence nearly every time, so the capital is the word's own rather than the sentence's.
The pronoun I and its contractions are capitalized the same way but are not names."""

from collections import Counter
from collections.abc import Iterable

from normalize import written_runs

# A word counts as a name once the source shows it this often, almost always capitalized.
_MINIMUM_OCCURRENCES = 20
_CAPITALIZED_SHARE = 0.9


def is_pronoun_i(word: str) -> bool:
    """The keyboard's rule in WordCasing.capitalizingPronoun: "i" and its "i'" contractions."""
    return word[:1] == "i" and (len(word) == 1 or word[1] in "'’")


def capitalized_names(texts: Iterable[str]) -> set[str]:
    seen: Counter[str] = Counter()
    capitalized: Counter[str] = Counter()
    for text in texts:
        for run in written_runs(text):
            # The first word of a run may be capitalized only for starting it.
            for word in run[1:]:
                lowered = word.lower()
                seen[lowered] += 1
                if word[:1].isupper():
                    capitalized[lowered] += 1
    return {
        word
        for word, count in seen.items()
        if count >= _MINIMUM_OCCURRENCES
        and capitalized[word] / count >= _CAPITALIZED_SHARE
        and not is_pronoun_i(word)
    }


def mentions_any(text: str, names: set[str]) -> bool:
    return any(word.lower() in names for run in written_runs(text) for word in run)
