"""Writes the words the predictive keyboard spells with capitals, such as "Jennifer" or
"iPhone": one per line as the lowercase word, a tab, and that spelling, in byte order of
the lowercase word, for `CapitalizedSpellings` in KeyVoxPredictiveKeyboard.

A word is listed when its dictionary's SCOWL word list (from `scowl_words.sh`) spells it
only one way, with capitals. Left out, so they stay as typed:
- a word the word list also spells in lowercase ("will", "bob") or in more than one way;
- a spelling with capitals in a row ("NASA", "CDs");
- a word the written sources show in lowercase more often than as spelled, away from where
  a sentence or quotation begins ("grey", or "th" after a number).
Abbreviations ending in a period are skipped, since a typed word never does.
"""

import argparse
from collections import Counter, defaultdict
from pathlib import Path

from extract_sentences import READERS
from normalize import written_runs

# The sources written with care for capitals; video transcripts often are not.
WRITTEN_SOURCES = ("oasst2", "tatoeba")


def has_capitals_in_a_row(spelling: str) -> bool:
    return any(first.isupper() and second.isupper() for first, second in zip(spelling, spelling[1:]))


def capitals_only_spellings(scowl_words: Path) -> dict[str, str]:
    """Lowercase word to its one spelling, for words the word list spells only with capitals."""
    with open(scowl_words, encoding="utf-8") as lines:
        spellings = [line.rstrip("\n").replace("’", "'") for line in lines]
    spellings = [spelling for spelling in spellings if spelling and not spelling.endswith(".")]
    lowercase = {spelling for spelling in spellings if spelling == spelling.lower()}
    capitalized: defaultdict[str, set[str]] = defaultdict(set)
    for spelling in spellings:
        if spelling != spelling.lower():
            capitalized[spelling.lower()].add(spelling)
    return {
        word: next(iter(forms))
        for word, forms in capitalized.items()
        if word not in lowercase and len(forms) == 1 and not has_capitals_in_a_row(next(iter(forms)))
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("scowl_words", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()

    spellings = capitals_only_spellings(arguments.scowl_words)
    as_spelled: Counter[str] = Counter()
    in_lowercase: Counter[str] = Counter()
    for name in WRITTEN_SOURCES:
        for text in READERS[name](arguments.data_dir / "sources" / name):
            for run in written_runs(text):
                for word in run[1:]:
                    key = word.lower()
                    if key not in spellings:
                        continue
                    if word == spellings[key]:
                        as_spelled[key] += 1
                    elif word == key:
                        in_lowercase[key] += 1

    rows = sorted(
        (word, spelling)
        for word, spelling in spellings.items()
        if in_lowercase[word] <= as_spelled[word]
    )
    with open(arguments.output, "w", encoding="utf-8") as listing:
        listing.writelines(f"{word}\t{spelling}\n" for word, spelling in rows)
    print(f"{arguments.output}: {len(rows)} words")


if __name__ == "__main__":
    main()
