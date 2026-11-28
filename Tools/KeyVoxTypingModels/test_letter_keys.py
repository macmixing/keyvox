"""Checks the one rule for which key types a letter (`letter_keys.py`), on long-press lists written
here: a letter's own key first, then the key whose long-press list offers it, then the first key of
its plain spelling. Run with `python -m unittest test_letter_keys`."""

import tempfile
import unittest
from pathlib import Path

from letter_keys import held_keys, key_for

KEYS = set("aeiou") | {"s", "x"}
# A long-press list offering a letter its Unicode plain spelling would put on another key.
HELD = "\n".join((
    "e\tright\te é ê",
    "x\tright\tx ō",
    "?\tright\t? ¿",
)) + "\n"


class LetterKeyTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "held_key_characters.txt"
        self.path.write_text(HELD, encoding="utf-8")
        self.held = held_keys(self.path)

    def test_reads_each_offered_character_by_its_key(self):
        self.assertEqual(self.held, {"é": "e", "ê": "e", "ō": "x", "¿": "?"})

    def test_reads_no_lists_without_a_file(self):
        self.assertEqual(held_keys(self.path.with_name("missing.txt")), {})

    def test_types_a_letter_with_its_own_key_there(self):
        self.assertEqual(key_for("e", KEYS, self.held), "e")

    def test_types_an_offered_letter_on_the_key_that_offers_it(self):
        self.assertEqual(key_for("ō", KEYS, self.held), "x")

    def test_falls_back_to_the_plain_spelling(self):
        self.assertEqual(key_for("ō", KEYS), "o")
        self.assertEqual(key_for("ß", KEYS, self.held), "s")

    def test_gives_no_key_without_either(self):
        self.assertIsNone(key_for("ø", KEYS, self.held))
        self.assertIsNone(key_for("¿", KEYS, self.held))


if __name__ == "__main__":
    unittest.main()
