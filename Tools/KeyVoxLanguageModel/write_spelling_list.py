"""Writes the words a typing language spells right, one per line, for the swipe vocabulary's
misspelling rule (`write_swipe_vocabulary.py`), which never leaves out a word the list holds.

English's are SCOWL's size 80 in every spelling, American, British, Canadian, and Australian
(scowl_words.sh). Another language's are its keyboard word list's words and every form of its
lexicons (`LexiconVocabulary`: the AOSP LatinIME word list and, such as Wikidata Lexemes, the
lexicons that settle its capitals)."""

import argparse
import subprocess
from pathlib import Path

from languages import LANGUAGES, language_argument
from readers import source_paths
from vocabulary.latinime_words import latinime_words
from vocabulary.lexicon_forms import lexicon_forms

SCOWL_SIZE = "80"
SCOWL_SPELLINGS = "A,B,Z,C,D"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()
    vocabulary = LANGUAGES[arguments.language].vocabulary
    if vocabulary is None:
        subprocess.run(["./scowl_words.sh", SCOWL_SIZE, str(arguments.output), SCOWL_SPELLINGS], check=True)
        return
    words = lexicon_forms(arguments.data_dir, vocabulary.lexicons)
    for path in source_paths(arguments.data_dir, vocabulary.word_list):
        words.update(latinime_words(path))
    arguments.output.write_text("".join(f"{word}\n" for word in sorted(words)), encoding="utf-8")
    print(f"{arguments.output}: {len(words)} words")


if __name__ == "__main__":
    main()
