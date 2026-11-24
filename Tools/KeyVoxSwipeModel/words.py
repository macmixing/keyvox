"""Turns a written word into what a swipe can express: its letters, then the keys it
passes over.

A swipe draws letters only, so a word's swipe form drops everything that is not a letter
(apostrophes, hyphens, punctuation), folds case, and folds accents onto their base letter.
A swipe cannot tell a doubled letter from a single one, so the key path collapses
consecutive repeats."""

import unicodedata


def letter_form(word: str) -> str:
    decomposed = unicodedata.normalize("NFD", word.casefold())
    return "".join(character for character in decomposed if unicodedata.category(character)[0] == "L")


def key_path(form: str, key_index: dict[str, int]) -> list[int] | None:
    """The layout keys a swipe of `form` passes, or None when a letter has no key."""
    path: list[int] = []
    for character in form:
        key = key_index.get(character)
        if key is None:
            return None
        if not path or path[-1] != key:
            path.append(key)
    return path
