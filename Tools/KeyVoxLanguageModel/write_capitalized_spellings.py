"""Writes the words the predictive keyboard spells with capitals, such as "Jennifer" or
"iPhone": one per line as the lowercase word, a tab, and that spelling, in byte order of
the lowercase word, for `CapitalizedSpellings` in KeyVoxLinguistics.

A word is listed when its language's vocabulary (write_vocabulary.py; for English, SCOWL's
size 60) spells it only one way, with capitals. Left out, so they stay as typed:
- a word the common part of the vocabulary (for English, SCOWL's size 50) also spells in
  lowercase ("will", "bob"), while a rare lowercase sense does not count ("charlie", "batman");
- a word spelled with capitals in more than one way;
- a spelling with capitals in a row ("NASA", "CDs"), unless the language's measured spellings
  (for English, `measured_spellings.txt`) list it because the system keyboard was measured
  writing it that way ("iOS");
- a word the written sources show in lowercase more often than as spelled, away from where
  a sentence or quotation begins ("grey", or "th" after a number);
- a word a pattern of `--leave-out` matches whole, a word the language's dictionary leaves out
  too (`Tools/KeyVoxTypingModels` writes a language's patterns as `work/offensive_words.txt`).
Abbreviations ending in a period are skipped, since a typed word never does.
"""

import argparse
import re
import unicodedata
from collections import Counter, defaultdict
from collections.abc import Callable
from pathlib import Path

from languages import LANGUAGES, language_argument
from normalize import written_runs
from readers import read_source

# The sources written with care for capitals; video transcripts often are not. Tatoeba is
# read whole: the language data leaves out its sentences that mention its recurring
# characters only so the characters stop opening sentences, and those sentences still show
# how words are written.
WRITTEN_SOURCES = ("oasst2", "tatoeba")


def letter_form(word: str, keys: str = "", spellings: dict[str, str] | None = None) -> str:
    """The word's letters only, with case and accents folded, as `Tools/KeyVoxTypingModels`
    matches its left-out words; but for a letter of `keys`, which keeps its accents, and a letter
    of `spellings`, written as the letters it gives, as a swipe model reads its words."""
    form = []
    for character in unicodedata.normalize("NFC", word.casefold()):
        if character in keys:
            form.append(character)
        elif spellings and character in spellings:
            form.append(spellings[character])
        else:
            form.extend(letter for letter in unicodedata.normalize("NFD", character)
                        if unicodedata.category(letter)[0] == "L")
    return "".join(form)


def leave_out_matcher(path: Path | None) -> Callable[[str], bool]:
    """Whether a pattern of `path`, a regular expression a line, matches a word's letter form whole;
    never, with no file or no pattern."""
    lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line] if path else []
    if not lines:
        return lambda word: False
    expression = re.compile("|".join(f"(?:{line})" for line in lines))
    return lambda word: expression.fullmatch(letter_form(word)) is not None


def has_capitals_in_a_row(spelling: str) -> bool:
    return any(first.isupper() and second.isupper() for first, second in zip(spelling, spelling[1:]))


def read_measured_spellings(path: Path) -> set[str]:
    with open(path, encoding="utf-8") as lines:
        return {line.strip() for line in lines if line.strip() and not line.startswith("#")}


def keeps_capitals_in_a_row(spelling: str, measured: set[str]) -> bool:
    """Whether `spelling`, or the word it is the possessive of, is a measured spelling."""
    return spelling in measured or spelling.removesuffix("'s") in measured


def read_spellings(path: Path) -> list[str]:
    with open(path, encoding="utf-8") as lines:
        spellings = [line.rstrip("\n").replace("’", "'") for line in lines]
    return [spelling for spelling in spellings if spelling and not spelling.endswith(".")]


def capitals_only_spellings(scowl_words: Path, common_words: Path, measured: set[str]) -> dict[str, str]:
    """Lowercase word to its one spelling, for words spelled only with capitals unless in a
    rare lowercase sense."""
    spellings = read_spellings(scowl_words)
    lowercase = {spelling for spelling in read_spellings(common_words) if spelling == spelling.lower()}
    capitalized: defaultdict[str, set[str]] = defaultdict(set)
    for spelling in spellings:
        if spelling != spelling.lower():
            capitalized[spelling.lower()].add(spelling)
    return {
        word: next(iter(forms))
        for word, forms in capitalized.items()
        if word not in lowercase
        and len(forms) == 1
        and (
            not has_capitals_in_a_row(next(iter(forms)))
            or keeps_capitals_in_a_row(next(iter(forms)), measured)
        )
    }


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("scowl_words", type=Path, help="The vocabulary (for English, SCOWL's size 60).")
    parser.add_argument("common_words", type=Path, help="Its common part (for English, SCOWL's size 50).")
    parser.add_argument("output", type=Path)
    parser.add_argument("--leave-out", type=Path,
                        help="the words to leave out, a regular expression a word's letter form must match whole a line "
                             "(Tools/KeyVoxTypingModels writes a language's as work/offensive_words.txt)")
    arguments = parser.parse_args()
    language = LANGUAGES[arguments.language]
    is_left_out = leave_out_matcher(arguments.leave_out)

    spellings = capitals_only_spellings(
        arguments.scowl_words,
        arguments.common_words,
        read_measured_spellings(language.measured_spellings) if language.measured_spellings else set(),
    )
    as_spelled: Counter[str] = Counter()
    in_lowercase: Counter[str] = Counter()
    for name in WRITTEN_SOURCES:
        for text in read_source(arguments.data_dir, language.source(name)):
            for run in written_runs(text, language.text_rules):
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
        if in_lowercase[word] <= as_spelled[word] and not is_left_out(word)
    )
    with open(arguments.output, "w", encoding="utf-8") as listing:
        listing.writelines(f"{word}\t{spelling}\n" for word, spelling in rows)
    print(f"{arguments.output}: {len(rows)} words")


if __name__ == "__main__":
    main()
