"""Writes the patterns of the words the keyboard's word data leaves out, one a line, to
`<data_dir>/work/offensive_words.txt`: the terms of the language's profanity list
(`sources.PROFANITY_LIST`, `profanity_list` in `typing_languages.py`) tagged racial or anti-LGBTQ
at any severity, or religious at strong severity or above, which leaves out religious
exclamations. Phrases, terms with a space, are left aside, as no word is one. The pinned list has
English terms alone, so for any other language the file is empty and no word is left out.

Each pattern is a regular expression a word's letter form (its letters only, case and accents
folded, as a swipe draws it) must match whole: a term's letters, read the same way, the list's "*"
after a letter, for that letter one or more times, becoming "+", then optionally its plural or
possessive ending, "s", or "es" after a term ending in s, x, z, ch, sh, or o, and, for a term
ending in a consonant and "y", its plural with "ies" for the "y" (an apostrophe is no letter, so
"'s" reads as "s"). The list names terms, not the words built on them, and matching
inside words, as it allows, would take ordinary words that contain a term. The dictionary (`write_dictionary_inputs.py`) leaves out every word
one matches, with every word pair and three-word sequence holding one, and the swipe vocabulary
(`Tools/KeyVoxLanguageModel/write_swipe_vocabulary.py`) every candidate one matches."""

import argparse
import json
import re
import unicodedata
from pathlib import Path

from paths import DataPaths
from sources import profanity_list_path
from typing_languages import add_language_arguments, language_from

LEFT_OUT_TAGS = {"racial", "lgbtq"}
RELIGIOUS_TAG = "religious"
# The list's severities run from 1, mild, to 4, severe.
STRONG_SEVERITY = 3
# A term's plural or possessive ending, as English writes it.
PLURAL_OR_POSSESSIVE = r"(?:s|(?<=[sxzo])es|(?<=[cs]h)es)?"
# A term ending in a consonant and "y", which a plural writes with "ies" for the "y".
CONSONANT_Y = re.compile(r"[^aeiou*]\*?y$")
Y_PLURAL = "ies"
REPEAT = "*"


def is_left_out(entry: dict) -> bool:
    tags = set(entry.get("tags") or [])
    return bool(tags & LEFT_OUT_TAGS) or (RELIGIOUS_TAG in tags and entry["severity"] >= STRONG_SEVERITY)


def letter_form(word: str) -> str:
    decomposed = unicodedata.normalize("NFD", word.casefold())
    return "".join(character for character in decomposed if unicodedata.category(character)[0] == "L")


def term_letters(term: str) -> str:
    """The term read as a letter form, keeping its repeat marks."""
    return "".join(character if character == REPEAT else letter_form(character) for character in term)


def patterns(list_path: Path) -> list[str]:
    entries = json.loads(list_path.read_text(encoding="utf-8"))
    terms = sorted({term_letters(term) for entry in entries if is_left_out(entry)
                    for term in entry["match"].split("|") if " " not in term})
    def expression(letters: str) -> str:
        return re.escape(letters).replace(re.escape(REPEAT), "+")

    written = []
    for term in terms:
        if not term.strip(REPEAT):
            continue
        pattern = expression(term) + PLURAL_OR_POSSESSIVE
        if CONSONANT_Y.search(term):
            pattern = f"(?:{pattern}|{expression(term[:-1])}{Y_PLURAL})"
        written.append(pattern)
    return written


def read_matcher(path: Path) -> re.Pattern | None:
    """One expression matching a letter form whole when any pattern of `path` does, or None when
    the file has none."""
    lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line]
    return re.compile("|".join(f"(?:{line})" for line in lines)) if lines else None


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    add_language_arguments(parser)
    arguments = parser.parse_args()
    data_dir = arguments.data_dir
    paths = DataPaths(data_dir)
    language = language_from(arguments)
    if language.profanity_list is None:
        written = []
        print(f"the profanity list has no {language.identifier} terms; no word is left out")
    else:
        written = patterns(profanity_list_path(data_dir, language.profanity_list))
    paths.work.mkdir(parents=True, exist_ok=True)
    paths.offensive_words.write_text("".join(f"{pattern}\n" for pattern in written), encoding="utf-8")
    print(f"wrote {paths.offensive_words}: {len(written)} patterns")


if __name__ == "__main__":
    main()
