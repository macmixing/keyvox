"""Writes the patterns of the words the keyboard's word data leaves out, one a line, to
`<data_dir>/work/offensive_words.txt`: the terms of the English profanity list
(`sources.PROFANITY_LIST`) tagged racial or anti-LGBTQ at any severity, or religious at strong
severity or above, which leaves out religious exclamations. Phrases, terms with a space, are left
aside, as no word is one.

Each pattern is a regular expression a word's letter form (its letters only, case and accents
folded, as a swipe draws it) must match whole: the list's "*" after a letter, for that letter one
or more times, becomes "+". The dictionary (`write_dictionary_inputs.py`) leaves out every word
one matches, with every word pair and three-word sequence holding one, and the swipe vocabulary
(`Tools/KeyVoxLanguageModel/write_swipe_vocabulary.py`) every candidate one matches."""

import argparse
import json
import re
import unicodedata
from pathlib import Path

from paths import DataPaths
from sources import profanity_list_path

LEFT_OUT_TAGS = {"racial", "lgbtq"}
RELIGIOUS_TAG = "religious"
# The list's severities run from 1, mild, to 4, severe.
STRONG_SEVERITY = 3


def is_left_out(entry: dict) -> bool:
    tags = set(entry.get("tags") or [])
    return bool(tags & LEFT_OUT_TAGS) or (RELIGIOUS_TAG in tags and entry["severity"] >= STRONG_SEVERITY)


def patterns(list_path: Path) -> list[str]:
    entries = json.loads(list_path.read_text(encoding="utf-8"))
    terms = sorted({term for entry in entries if is_left_out(entry)
                    for term in entry["match"].split("|") if " " not in term})
    return [re.escape(term).replace(r"\*", "+") for term in terms]


def letter_form(word: str) -> str:
    decomposed = unicodedata.normalize("NFD", word.casefold())
    return "".join(character for character in decomposed if unicodedata.category(character)[0] == "L")


def read_matcher(path: Path) -> re.Pattern:
    """One expression matching a letter form whole when any pattern of `path` does."""
    lines = [line for line in path.read_text(encoding="utf-8").splitlines() if line]
    return re.compile("|".join(f"(?:{line})" for line in lines))


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)
    written = patterns(profanity_list_path(data_dir))
    paths.work.mkdir(parents=True, exist_ok=True)
    paths.offensive_words.write_text("".join(f"{pattern}\n" for pattern in written), encoding="utf-8")
    print(f"wrote {paths.offensive_words}: {len(written)} patterns")


if __name__ == "__main__":
    main()
