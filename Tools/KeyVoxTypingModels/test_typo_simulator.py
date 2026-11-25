"""Checks that the typo simulator types a word's apostrophe after everything it typed for the
letters before it, whatever it left out, doubled, or added before it. Run with
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


def simulator(**forced):
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
        "letters": {position: dict.fromkeys(LAYOUT.letters, 1) for position in POSITIONS},
        "typos": {"letters": {kind: {"ix": 1} for kind in LETTERED_KINDS}},
    }
    return TypoSimulator(LAYOUT, measurements, calibration, seed=1)


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
