"""Writes the patterns of the words the keyboard's word data leaves out, one a line, to
`<data_dir>/work/offensive_words.txt`: for English, the terms of the profanity list
(`sources.PROFANITY_LIST`, `profanity_list` in `typing_languages.py`) tagged racial or anti-LGBTQ
at any severity, or religious at strong severity or above, which leaves out religious
exclamations; for another language, the slurs of its Multilingual HateCheck dataset
(`sources.MULTILINGUAL_HATECHECK`, `hatecheck_dataset`) that target the groups those tags name
(`LEFT_OUT_TARGETS`), so slurs against women and disabled people stay, as English's list keeps them
apart from those tags. Phrases, terms with a space, are left aside, as no word is one. A language
with neither list leaves no word out.

Each pattern is a regular expression a word's letter form (its letters only, case and accents
folded, as a swipe draws it) must match whole: a term's letters, read the same way, the list's "*"
after a letter, for that letter one or more times, becoming "+", then optionally its plural or
possessive ending, "s", or "es" after a term ending in s, x, z, ch, sh, or o, and, for a term
ending in a consonant and "y", its plural with "ies" for the "y" (an apostrophe is no letter, so
"'s" reads as "s"). The list names terms, not the words built on them, and matching
inside words, as it allows, would take ordinary words that contain a term. A HateCheck slur's
pattern is its letters alone: the dataset writes each slur in the forms its sentences use, plurals
included (`hatecheck_slurs.py`), so each form is a pattern of its own and no ending is added. The
dictionary (`write_dictionary_inputs.py`) leaves out every word one matches, with every word pair
and three-word sequence holding one, and the swipe vocabulary
(`Tools/KeyVoxLanguageModel/write_swipe_vocabulary.py`) every candidate one matches."""

import argparse
import json
import re
import unicodedata
from pathlib import Path

import hatecheck_slurs
from paths import DataPaths
from sources import hatecheck_file, profanity_list_path
from typing_languages import add_language_arguments, language_from

LEFT_OUT_TAGS = {"racial", "lgbtq"}
# HateCheck's target groups of the slurs the tags above and the religious tag cover.
LEFT_OUT_TARGETS = {"black people", "immigrants", "indigenous people", "gay people", "trans people",
                    "jews", "muslims"}
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


def left_out_slurs(cases_path: Path) -> set[str]:
    """The single-word HateCheck slurs that target a left-out group, in lowercase."""
    return {slur.lower() for group, slurs in hatecheck_slurs.slurs(cases_path).items()
            if group in LEFT_OUT_TARGETS for slur in slurs if " " not in slur}


def hatecheck_patterns(slurs: set[str]) -> list[str]:
    """A pattern for each slur: its letter form."""
    forms = {letter_form(slur) for slur in slurs}
    return sorted(re.escape(form) for form in forms if form)


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
    if language.profanity_list is not None:
        written = patterns(profanity_list_path(data_dir, language.profanity_list))
    elif language.hatecheck_dataset is not None:
        written = hatecheck_patterns(
            left_out_slurs(data_dir / hatecheck_file(language.hatecheck_dataset).path))
    else:
        written = []
        print(f"no list of {language.identifier} slurs is pinned; no word is left out")
    paths.work.mkdir(parents=True, exist_ok=True)
    paths.offensive_words.write_text("".join(f"{pattern}\n" for pattern in written), encoding="utf-8")
    print(f"wrote {paths.offensive_words}: {len(written)} patterns")


if __name__ == "__main__":
    main()
