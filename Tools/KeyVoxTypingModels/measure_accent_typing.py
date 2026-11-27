"""Measures how often people writing a typing language type a letter that has no key of its own
on the language's default letter layout, such as French "é" or German "ß", as its plain letters
instead, "e" or "ss", and writes it to `<data_dir>/work/simulation/accent_typing.json` for the typo
simulator.

A letter without a key is typed with a long press on its base letter's key, or, left plain, with
that key alone. How often writers leave it plain is measured from the language build's sentences
of `accent_source` (`typing_languages.py`), text people typed: for each dictionary word with one
such letter, however many times, whose plain spelling is no dictionary word (so "très", whose
plain "tres" is no word, but not "où", whose plain "ou" is one), how often the source writes the
word each way. A letter seen fewer than `FEWEST_WORDS` times takes the rate of every such letter
together.

Letters with a key, such as German "ü" or Spanish "ñ" on their layouts, are tapped as any other
letter (`touch_spread.py`): writers leave them plain far more rarely, as the measurements below the
rates show."""

import argparse
import json
import unicodedata
from collections import Counter
from pathlib import Path

import language_build
from paths import DataPaths
from typing_languages import add_language_arguments, language_from

FEWEST_WORDS = 200
# Letters whose plain spelling is two letters.
PLAIN_SPELLINGS = {"ß": "ss", "œ": "oe", "æ": "ae"}


def plain_spelling(letter):
    """The letters a letter is written with when typed without its accent."""
    if letter in PLAIN_SPELLINGS:
        return PLAIN_SPELLINGS[letter]
    decomposed = unicodedata.normalize("NFD", letter)
    return "".join(character for character in decomposed if not unicodedata.combining(character))


def plain_counts(words, counts, letters):
    """For each of `letters`, how often `counts` writes the words with it as spelled and plain."""
    measured = {letter: [0, 0] for letter in letters}
    for word in words:
        present = {character for character in word if character in letters}
        if len(present) != 1:
            continue
        letter = present.pop()
        plain = word.replace(letter, plain_spelling(letter))
        if plain in words:
            continue
        measured[letter][0] += counts[word]
        measured[letter][1] += counts[plain]
    return measured


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    add_language_arguments(parser)
    arguments = parser.parse_args()
    paths = DataPaths(arguments.data_dir)
    language = language_from(arguments)
    if language.accent_source is None:
        raise SystemExit(f"{language.identifier} names no source to measure its accents in")

    keys = {letter for letters, _ in language.letter_rows() for letter in letters}
    words = {line.split("\t", 1)[0] for line in
             paths.dictionary_unigrams.read_text(encoding="utf-8").splitlines()}
    counts = Counter()
    for sentence in language_build.sentences(paths, language.accent_source):
        counts.update(sentence)

    keyless = sorted({character for word in words for character in word
                      if character.isalpha() and character not in keys
                      and plain_spelling(character)[:1] in keys})
    keyed = sorted(letter for letter in keys if plain_spelling(letter) != letter
                   and plain_spelling(letter) and all(c in keys for c in plain_spelling(letter)))
    measured = plain_counts(words, counts, set(keyless))
    kept_total = sum(kept for kept, _ in measured.values())
    plain_total = sum(plain for _, plain in measured.values())
    pooled = plain_total / max(1, kept_total + plain_total)

    letters = {}
    for letter in keyless:
        kept, plain = measured[letter]
        enough = kept + plain >= FEWEST_WORDS
        letters[letter] = {
            "key": plain_spelling(letter)[0], "plain": plain_spelling(letter),
            "spelled": kept, "plain_spelled": plain,
            "plain_rate": plain / (kept + plain) if enough else pooled, "measured": enough,
        }
    keyed_measured = plain_counts(words, counts, set(keyed))
    result = {
        "language": language.identifier, "source": language.accent_source,
        "letters": letters, "pooled_plain_rate": pooled,
        "letters_with_keys": {letter: {"spelled": kept, "plain_spelled": plain}
                              for letter, (kept, plain) in keyed_measured.items()},
    }
    paths.simulation.mkdir(parents=True, exist_ok=True)
    paths.accent_typing.write_text(
        json.dumps(result, indent=2, ensure_ascii=False), encoding="utf-8")
    for letter, values in letters.items():
        if values["measured"]:
            print(f"{letter} as {values['plain']}: {values['plain_rate']:.1%} of "
                  f"{values['spelled'] + values['plain_spelled']:,} words")
    pooled_letters = "".join(letter for letter, values in letters.items() if not values["measured"])
    print(f"every letter without a key together: {pooled:.1%} of "
          f"{kept_total + plain_total:,} words; taken by {pooled_letters or 'none'}")
    for letter, (kept, plain) in keyed_measured.items():
        print(f"{letter} (has a key) as {plain_spelling(letter)}: "
              f"{plain / max(1, kept + plain):.1%} of {kept + plain:,} words")


if __name__ == "__main__":
    main()
