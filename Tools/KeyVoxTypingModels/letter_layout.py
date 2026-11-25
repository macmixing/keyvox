"""Where a typing language's letter keys sit, in key pitches: one pitch is the distance between
neighboring key centers across a row, and between rows.

The rows come from the language's letter rows, which `letter_rows` reads; it is the one place
the typo simulator reads key geometry from. Each key is a one-pitch square, as the keyboard's
`LetterKeyLayout` lays them out: row `r` spans `r` to `r + 1` down, and a row's `i`th key spans
its offset plus `i` to its offset plus `i + 1` across."""

import json
from pathlib import Path

PREDICTIVE_DATA = (Path(__file__).resolve().parent / "../../Packages/KeyVoxPredictiveKeyboard/"
                   "Sources/KeyVoxPredictiveKeyboard/PredictiveData").resolve()


def letter_rows(language):
    """The language's letter rows, top to bottom, as (letters, offset in key pitches)."""
    manifest = json.loads((PREDICTIVE_DATA / language / "language.json").read_text(encoding="utf-8"))
    return [(row["letters"], float(row["offset"])) for row in manifest["letterRows"]]


class LetterLayout:
    def __init__(self, rows):
        self.keys = {}
        for row_index, (letters, offset) in enumerate(rows):
            for column, letter in enumerate(letters):
                self.keys[letter] = (offset + column, row_index)
        self.letters = tuple(self.keys)

    @classmethod
    def for_language(cls, language):
        return cls(letter_rows(language))

    def bounds(self, letter):
        """The key's left, right, top, and bottom edges."""
        left, top = self.keys[letter]
        return left, left + 1.0, float(top), top + 1.0

    def center(self, letter):
        left, top = self.keys[letter]
        return left + 0.5, top + 0.5

    def relation(self, intended, typed):
        """How the typed key sits from the intended one: `row` for a key beside it in its row,
        `adjacent_row` for one in the row above or below that overlaps it across, and `far` for
        any other key."""
        left, row = self.keys[intended]
        typed_left, typed_row = self.keys[typed]
        if typed_row == row:
            return "row" if abs(typed_left - left) == 1.0 else "far"
        if abs(typed_row - row) == 1 and abs(typed_left - left) < 1.0:
            return "adjacent_row"
        return "far"

    def neighbors(self, letter):
        """The keys beside the letter's key in its row and the rows above and below."""
        return tuple(other for other in self.letters
                     if other != letter and self.relation(letter, other) != "far")
