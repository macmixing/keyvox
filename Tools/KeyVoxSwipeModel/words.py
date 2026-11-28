"""Turns a written word into what a swipe can express: its letters, then the keys it
passes over.

A swipe draws letters only, so a word's swipe form drops everything that is not a letter
(apostrophes, hyphens, punctuation), folds case, and folds accents onto their base letter,
except on a letter of `keys`, the letters with keys of their own, which keeps its accents (German
"ä" on a layout with an "ä" key), and a letter of `spellings`, which a swipe spells with other
letters (French "œ" as "oe"), as the keyboard's `SwipeLetterForm` reads words; a language's are
its swipe model's (`swipe_letters`). By default the key path collapses consecutive repeats; with
`keep_doubles` it keeps them, so a model can learn the lingering that marks a doubled letter."""

import json
import unicodedata
from pathlib import Path

PREDICTIVE_DATA = Path(__file__).resolve().parents[2] / (
    "Packages/KeyVoxPredictiveKeyboard/Sources/KeyVoxPredictiveKeyboard/PredictiveData")


def letter_form(word: str, keys: str = "", spellings: dict[str, str] | None = None) -> str:
    form = []
    for character in unicodedata.normalize("NFC", word.casefold()):
        if character in keys:
            form.append(character)
        elif spellings and character in spellings:
            form.append(spellings[character])
        else:
            form.extend(letter for letter in unicodedata.normalize("NFD", character)
                        if unicodedata.category(letter)[0] == "L")
    return "".join(form)


def swipe_letters(language: str) -> tuple[str, dict[str, str]]:
    """A bundled typing language's swipe model's letters and spelled letters (its swipe.json)."""
    settings = json.loads((PREDICTIVE_DATA / language / "swipe.json").read_text(encoding="utf-8"))
    return settings["letters"], settings.get("spelledLetters", {})


def key_path(form: str, key_index: dict[str, int], keep_doubles: bool = False) -> list[int] | None:
    """The layout keys a swipe of `form` passes, or None when a letter has no key."""
    path: list[int] = []
    for character in form:
        key = key_index.get(character)
        if key is None:
            return None
        if keep_doubles or not path or path[-1] != key:
            path.append(key)
    return path


def ctc_frames_needed(path: list[int]) -> int:
    """Frames a CTC alignment of `path` needs: one per key, plus a blank between repeats."""
    return len(path) + sum(1 for before, after in zip(path, path[1:]) if before == after)
