"""Which letter key types a letter, the one rule the typo simulator (`measure_accent_typing.py`) and
the suggestion reader (`latinime_candidates.py`) both follow.

A letter with a key of its own is typed there. A letter without one is typed with a long press on
the key whose long-press list offers it, as the keyboard aims a popup letter at the key that offers
it: the language's `held_key_characters.txt` beside its `language.json` lists each key's letters
(`held_keys`). A letter no listed key offers, or a language without the file, takes the first key
of the letter's plain spelling: its base letters with its accents left off (its Unicode
decomposition), or, for a letter with no accent to leave off, its Unicode case folding, which
writes some letters with two. A letter neither gives a key has none."""

import unicodedata

HELD_KEY_CHARACTERS = "held_key_characters.txt"


def plain_spelling(letter):
    """The letters a letter is written with when typed without its accent: its decomposition less
    its accents, or its case folding when it has no accent to leave off."""
    decomposed = unicodedata.normalize("NFD", letter)
    plain = "".join(character for character in decomposed if not unicodedata.combining(character))
    return plain if plain != letter else letter.casefold()


def held_keys(path):
    """Each character a key's long-press list offers, by the first key in the file that offers it,
    from a `held_key_characters.txt` (a key, its popup's direction, and the characters it offers,
    a tab between each, the characters separated by spaces), or none when there is no file."""
    if not path.exists():
        return {}
    offered = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        fields = line.split("\t")
        if len(fields) < 3:
            continue
        key = fields[0]
        for character in fields[2].split():
            if character != key:
                offered.setdefault(character, key)
    return offered


def key_for(letter, keys, held=None):
    """The letter key that types the letter, of the layout's `keys`, from the long-press lists
    `held` (`held_keys`) or else the letter's plain spelling, or None."""
    if letter in keys:
        return letter
    if not letter.isalpha():
        return None
    if held and held.get(letter) in keys:
        return held[letter]
    first = plain_spelling(letter)[:1]
    return first if first in keys else None
