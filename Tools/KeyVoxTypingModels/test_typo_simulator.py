"""Checks that the typo simulator types a word's apostrophe after everything it typed for the
letters before it, whatever it left out, doubled, or added before it; that it types a letter
without a key on its base letter's key, as spelled or plain at its rate; and that on another
layout than ITE's it adds extra keys beside a letter on that layout. Run with
`python -m unittest test_typo_simulator`."""

import unittest

from letter_layout import LetterLayout
from typo_kinds import LETTERED_KINDS, LONGEST_COUNTED_LENGTH, POSITIONS
from typo_simulator import TypoSimulator

LAYOUT = LetterLayout.for_language("en")
# Rates of one kind's mistake that make it happen every time, and spreads no tap misses at.
ALWAYS = 10.0
NARROW = 0.08
LETTER_KINDS = ("omission", "substitution_far", "doubled", "insertion_neighbor", "insertion_far")


# German's letter rows, with "ü", "ö", and "ä" keys and no "ß" key.
GERMAN = LetterLayout([("qwertzuiopü", 0.0), ("asdfghjklöä", 0.0), ("yxcvbnm", 2.0)])


def simulator(layout=LAYOUT, accents=None, measured_layout=None, insertions=None, **forced):
    """A simulator that makes only the given mistakes, named as calibrated rates, every time."""
    rates = {"transposition": 0.0, "undoubled": 0.0, "apostrophe_dropped": 0.0}
    rates.update({f"{kind}/{position}": 0.0 for kind in LETTER_KINDS for position in POSITIONS})
    rates.update({kind.replace("__", "/"): ALWAYS for kind in forced})
    calibration = {
        "rates": rates,
        "spreads": {position: {"across": NARROW, "down": NARROW} for position in POSITIONS},
        "length_factors": {str(length): 1.0 for length in range(1, LONGEST_COUNTED_LENGTH + 1)},
        "sloppiness_shape": 1e9,
    }
    measurements = {
        "letters": {position: dict.fromkeys(layout.letters, 1) for position in POSITIONS},
        "typos": {"letters": {kind: {"ix": 1} for kind in LETTERED_KINDS}},
    }
    if insertions:
        measurements["typos"]["letters"]["insertion_neighbor"] = insertions
    return TypoSimulator(layout, measurements, calibration, seed=1, accents=accents,
                         measured_layout=measured_layout)


def sharp_s(plain_rate):
    return {"ß": {"key": "s", "plain": "ss", "plain_rate": plain_rate}}


class ApostropheTests(unittest.TestCase):
    def test_types_a_word_as_meant_without_mistakes(self):
        self.assertEqual(simulator().type_word("don't"), "don't")

    def test_follows_a_doubled_letter_before_it(self):
        self.assertEqual(simulator(doubled__middle=True).type_word("it's"), "itt's")

    def test_follows_a_left_out_letter_before_it(self):
        self.assertEqual(simulator(omission__first=True).type_word("it's"), "t's")

    def test_follows_an_added_letter_before_it(self):
        self.assertEqual(simulator(insertion_far__first=True).type_word("it's"), "ixt's")


if __name__ == "__main__":
    unittest.main()


class LetterWithoutKeyTests(unittest.TestCase):
    def test_types_it_as_spelled_from_its_base_key(self):
        self.assertEqual(simulator(GERMAN, sharp_s(0.0)).type_word("straße"), "straße")

    def test_types_it_plain_at_its_rate(self):
        self.assertEqual(simulator(GERMAN, sharp_s(1.0)).type_word("straße"), "strasse")

    def test_types_a_letter_with_a_key_on_that_key(self):
        self.assertEqual(simulator(GERMAN, sharp_s(1.0)).type_word("grün"), "grün")


class OtherLayoutTests(unittest.TestCase):
    def test_adds_the_key_at_the_measured_place_on_the_layout(self):
        # Measured on QWERTY, an extra "x" after "z" is the key right of it; on QWERTZ-German the
        # key right of "z" is "u".
        typed = simulator(GERMAN, measured_layout=LAYOUT, insertions={"zx": 1},
                          insertion_neighbor__last=True).type_word("az")
        self.assertEqual(typed, "azu")

    def test_adds_the_measured_letter_on_the_measured_layout(self):
        typed = simulator(insertions={"zx": 1}, insertion_neighbor__last=True).type_word("az")
        self.assertEqual(typed, "azx")
