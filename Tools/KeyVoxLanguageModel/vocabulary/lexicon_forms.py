"""Reads the word forms of a language's lexicons, each as written, with its capitals:
Wikidata Lexemes forms (`<language>_forms.tsv`: form, lemma, lexical category, features) and
the Grammalecte French lexicon (its zip's inflected-form column, "Flexion").

Forms are composed (NFC) and their typographic apostrophes made plain, as the keyboard reads
words."""

import io
import unicodedata
import zipfile
from collections.abc import Iterator
from functools import cache
from pathlib import Path

from readers import source_paths

# Wikidata's lexical category of proper nouns.
_PROPER_NOUN = "Q147276"
_GRAMMALECTE_FORM_COLUMN = "Flexion"


def _plain(form: str) -> str:
    return unicodedata.normalize("NFC", form).replace("’", "'")


def _wikidata_forms(path: Path) -> Iterator[tuple[str, str]]:
    """Each form with its lexeme's lexical category."""
    with open(path, encoding="utf-8") as rows:
        next(rows)
        for row in rows:
            form, _, category, _ = row.rstrip("\n").split("\t")
            yield _plain(form), category


def _grammalecte_forms(path: Path) -> Iterator[str]:
    with zipfile.ZipFile(path) as archive:
        name = next(name for name in archive.namelist() if name.endswith(".txt") and "lexique" in name)
        with io.TextIOWrapper(archive.open(name), encoding="utf-8") as lines:
            column = None
            for line in lines:
                fields = line.rstrip("\n").split("\t")
                if column is None:
                    if _GRAMMALECTE_FORM_COLUMN in fields:
                        column = fields.index(_GRAMMALECTE_FORM_COLUMN)
                    continue
                if len(fields) > column and fields[column]:
                    yield _plain(fields[column])


def lexicon_forms(data_dir: Path, lexicons) -> set[str]:
    """Every form of the lexicons, as written."""
    forms: set[str] = set()
    for lexicon in lexicons:
        for path in source_paths(data_dir, lexicon):
            if lexicon.name == "wikidata-lexemes":
                forms.update(form for form, _ in _wikidata_forms(path))
            else:
                forms.update(_grammalecte_forms(path))
    return forms


@cache
def capitalized_common_words(data_dir: Path, lexicons) -> frozenset[str]:
    """The words the language writes with a capital without their being names, lowercased:
    Wikidata forms spelled with a capital of a lexeme other than a proper noun, such as German
    nouns and the German formal pronoun."""
    words = set()
    for lexicon in lexicons:
        if lexicon.name != "wikidata-lexemes":
            continue
        for path in source_paths(data_dir, lexicon):
            words.update(
                form.lower() for form, category in _wikidata_forms(path)
                if form[:1].isupper() and category != _PROPER_NOUN
            )
    return frozenset(words)
