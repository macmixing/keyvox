"""Which letter key types a letter, the one rule the typo simulator (`measure_accent_typing.py`) and
the suggestion reader (`latinime_candidates.py`) both follow.

A letter with a key of its own is typed there. A letter without one is typed with a long press on
the first key of its plain spelling: its base letters with its accents left off (its Unicode
decomposition), or, for a letter with no accent to leave off, its Unicode case folding, which
writes some letters with two. A letter whose plain spelling does not start with a letter key has
no key."""

import unicodedata


def plain_spelling(letter):
    """The letters a letter is written with when typed without its accent: its decomposition less
    its accents, or its case folding when it has no accent to leave off."""
    decomposed = unicodedata.normalize("NFD", letter)
    plain = "".join(character for character in decomposed if not unicodedata.combining(character))
    return plain if plain != letter else letter.casefold()


def key_for(letter, keys):
    """The letter key that types the letter, of the layout's `keys`, or None."""
    if letter in keys:
        return letter
    if not letter.isalpha():
        return None
    first = plain_spelling(letter)[:1]
    return first if first in keys else None
