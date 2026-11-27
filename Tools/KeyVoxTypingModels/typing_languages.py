"""The typing languages the typing models are built for, and the build rules that differ between
them: where a language's words, counts, and typing come from, and its LatinIME dictionary's locale
and header attributes.

What the keyboard reads at run time comes from the language's `language.json`: its default letter
layout, whose letter keys the suggestion reader and the typo simulator tap, and its vowels, which
decide when the action model may correct a word. It is read from
`PredictiveData/<language>/language.json` in the package, or, with `--language-file`, from a file
elsewhere, for a language the package does not ship yet; its letter layout is always read from the
package's `letter_layouts`.

English is built from SCOWL's word lists, Tatoeba and OASST1's English text, and ITE's typing, as
the bundled files were. Every other language is built from what `Tools/KeyVoxLanguageModel` built
for it, linked into the data directory as `sources/language-build`: its vocabulary, its counts, and
its sentences, and its rankers learn from simulated typing alone."""

import argparse
import json
import sys
from dataclasses import dataclass, replace
from pathlib import Path

import regex

import words
from letter_layout import PREDICTIVE_DATA, letter_rows

ENGLISH_TEXT = "english"
LANGUAGE_BUILD_TEXT = "language-build"

# A word of a language built from a language build: Unicode letters with inner apostrophes, as
# Tools/KeyVoxLanguageModel's normalize.py splits text into words, shorter than LatinIME's
# MAX_WORD_LENGTH of 48 code points.
LANGUAGE_BUILD_WORD = regex.compile(r"\p{L}+(?:'\p{L}+)*")
LONGEST_WORD = 47


@dataclass(frozen=True)
class TypingLanguage:
    identifier: str
    # The locale the LatinIME dictionary's header names.
    locale: str
    # ENGLISH_TEXT or LANGUAGE_BUILD_TEXT: what the language's words, counts, and typing come from.
    text: str = LANGUAGE_BUILD_TEXT
    # Integer attributes the dictionary's header adds, by name.
    dictionary_attributes: tuple[tuple[str, int], ...] = ()
    # The language.json to read instead of the package's.
    language_file: Path | None = None

    @property
    def uses_english_text(self) -> bool:
        return self.text == ENGLISH_TEXT

    @property
    def manifest_path(self) -> Path:
        return self.language_file or PREDICTIVE_DATA / self.identifier / "language.json"

    @property
    def manifest(self) -> dict:
        return json.loads(self.manifest_path.read_text(encoding="utf-8"))

    def letter_rows(self):
        """The letter rows of the language's default letter layout (`letter_layout.letter_rows`)."""
        return letter_rows(self.manifest_path)

    @property
    def vowels(self) -> str:
        return self.manifest["vowels"]

    def valid_word(self, text: str) -> bool:
        """Whether the text is one word of the language as the builders read words."""
        if self.uses_english_text:
            return words.valid_word(text)
        return (1 <= len(text) <= LONGEST_WORD
                and LANGUAGE_BUILD_WORD.fullmatch(text) is not None)

    def dictionary_writer_options(self) -> list[str]:
        """The options `write_latinime_dictionary` writes the language's header with."""
        options = ["--locale", self.locale]
        for name, value in self.dictionary_attributes:
            options += ["--attribute", f"{name}={value}"]
        return options


# Each language build's locale is its AOSP word list's (`locale=` in the list's header).
LANGUAGES = {
    "en": TypingLanguage(identifier="en", locale="en_US", text=ENGLISH_TEXT),
    # The AOSP German word list's header asks for German umlaut processing, which lets "ue",
    # "oe", and "ae" type "ü", "ö", and "ä": WildChat's German turns write 1.1% of their words
    # with an umlaut so.
    "de": TypingLanguage(identifier="de", locale="de",
                         dictionary_attributes=(("REQUIRES_GERMAN_UMLAUT_PROCESSING", 1),)),
    "es": TypingLanguage(identifier="es", locale="es"),
    "fr": TypingLanguage(identifier="fr", locale="fr"),
}


def add_language_arguments(parser: argparse.ArgumentParser) -> None:
    parser.add_argument("--language", choices=sorted(LANGUAGES), default="en",
                        help="the typing language (default: en)")
    parser.add_argument("--language-file", type=Path,
                        help="the language.json to read in place of the package's")


def language_from(arguments: argparse.Namespace) -> TypingLanguage:
    language = LANGUAGES[arguments.language]
    if arguments.language_file is not None:
        language = replace(language, language_file=arguments.language_file.resolve())
    if not language.manifest_path.exists():
        raise SystemExit(f"{language.manifest_path} is missing: the package does not ship "
                         f"{language.identifier!r} yet; give its language.json with --language-file")
    if language.manifest["identifier"] != language.identifier:
        raise SystemExit(f"{language.manifest_path} is the language.json of "
                         f"{language.manifest['identifier']!r}, not {language.identifier!r}")
    return language


def main() -> None:
    """Prints what build_typing_models.sh needs of a language: `text`, its ENGLISH_TEXT or
    LANGUAGE_BUILD_TEXT, or `dictionary-options`, the options the dictionary writer takes."""
    parser = argparse.ArgumentParser(description=main.__doc__.splitlines()[0])
    parser.add_argument("query", choices=("text", "dictionary-options"))
    add_language_arguments(parser)
    arguments = parser.parse_args()
    language = language_from(arguments)
    if arguments.query == "text":
        print(language.text)
    else:
        sys.stdout.write("\n".join(language.dictionary_writer_options()) + "\n")


if __name__ == "__main__":
    main()
