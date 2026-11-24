"""Writes a typing language's vocabulary: its words with their capitals, one per line, as the
dictionary's word list for the builders of the capitalized spellings and the follower lists.
Writes two lists, the vocabulary and its common part, as SCOWL's sizes 60 and 50 serve English.

English's vocabulary is SCOWL (scowl_words.sh). Another language's is its AOSP LatinIME word
list, each word's capitals settled by its lexicons and its spelling checked where the language
has a check (vocabulary/spellings.py). Its common part is the spellings the word list itself
writes: a spelling only the lexicons add is a rare sense, such as a rare verb form spelled like a
common noun in lowercase. Only single words as the keyboard reads them are kept: letters with
inner apostrophes, composed with their accents.
"""

import argparse
import subprocess
import unicodedata
from pathlib import Path

from languages import LANGUAGES, language_argument
from normalize import is_word
from readers import source_paths
from vocabulary.hunspell_check import hunspell_accepted
from vocabulary.latinime_words import latinime_words
from vocabulary.lexicon_check import lexicon_accepted
from vocabulary.lexicon_forms import lexicon_forms
from vocabulary.spellings import settled_spellings

SCOWL_SIZE = "60"
SCOWL_COMMON_SIZE = "50"


def _plain(word: str) -> str:
    return unicodedata.normalize("NFC", word).replace("’", "'")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("common_output", type=Path)
    arguments = parser.parse_args()
    language = LANGUAGES[arguments.language]
    vocabulary = language.vocabulary

    if vocabulary is None:
        script = Path(__file__).with_name("scowl_words.sh")
        subprocess.run([str(script), SCOWL_SIZE, str(arguments.output)], check=True)
        subprocess.run([str(script), SCOWL_COMMON_SIZE, str(arguments.common_output)], check=True)
        return

    word_list = [
        word for path in source_paths(arguments.data_dir, vocabulary.word_list)
        for word in map(_plain, latinime_words(path)) if is_word(word)
    ]
    forms = lexicon_forms(arguments.data_dir, vocabulary.lexicons)
    lexicon = {form for form in forms if is_word(form)}
    if vocabulary.spelling_check == "hunspell":
        extension = source_paths(arguments.data_dir, vocabulary.spelling_dictionary)[0]
        check = lambda words: hunspell_accepted(words, extension)
    elif vocabulary.spelling_check == "lexicon":
        # The lexicon's elided forms, such as "l'", end in an apostrophe and so are no words.
        check = lambda words: lexicon_accepted(words, forms)
    else:
        check = None
    spellings = sorted(settled_spellings(word_list, lexicon, check, vocabulary.spelling_check_drops_words))
    listed = set(word_list)
    common = [spelling for spelling in spellings if spelling in listed]
    arguments.output.write_text("".join(spelling + "\n" for spelling in spellings), encoding="utf-8")
    arguments.common_output.write_text("".join(spelling + "\n" for spelling in common), encoding="utf-8")
    words = {spelling.lower() for spelling in spellings}
    print(f"{arguments.output}: {len(spellings)} spellings of {len(words)} words, {len(common)} common, "
          f"from {len(listed)} word-list spellings and {len(lexicon)} lexicon forms")


if __name__ == "__main__":
    main()
