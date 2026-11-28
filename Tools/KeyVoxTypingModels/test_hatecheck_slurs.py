"""Checks how a language's slurs are read from Multilingual HateCheck's test cases and turned into the
patterns of the words its dictionary leaves out, on test cases written here with stand-in words. Run
with `python -m unittest test_hatecheck_slurs`."""

import csv
import tempfile
import unittest
from pathlib import Path

import hatecheck_slurs
from offensive_words import hatecheck_patterns, left_out_slurs

COLUMNS = ("functionality", "test_case", "target_ident", "templ_id", "case_templ")
CASES = (
    # One template without placeholders: the slur is the word that varies most, not the article.
    ("slur_h", "Noch ein Kater.", "black people", "1", ""),
    ("slur_h", "Noch eine Katze.", "women", "1", ""),
    ("slur_h", "Noch ein Hund.", "gay people", "1", ""),
    ("slur_h", "Noch eine Hündin.", "trans people", "1", ""),
    # A template that marks its plural slur.
    ("slur_h", "Die sind nur Hunde.", "gay people", "2", "Die sind nur [SLR_P]."),
    # A slur of two words: its words are not slurs of their own.
    ("slur_h", "Das ist ein grauer Esel.", "Muslims", "3", "Das ist ein [SLR_S]."),
    ("slur_h", "Noch ein Esel.", "Muslims", "1", ""),
    # Not a slur case.
    ("derog_h", "Noch ein Fuchs.", "black people", "1", ""),
)


class HateCheckSlurTests(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.path = Path(directory.name) / "test.csv"
        with self.path.open("w", newline="", encoding="utf-8") as target:
            writer = csv.writer(target)
            writer.writerow(COLUMNS)
            writer.writerows(CASES)

    def test_reads_each_groups_slurs_in_their_written_forms(self):
        self.assertEqual(hatecheck_slurs.slurs(self.path), {
            "black people": {"Kater"}, "women": {"Katze"}, "gay people": {"Hund", "Hunde"},
            "trans people": {"Hündin"}, "muslims": {"grauer Esel"},
        })

    def test_leaves_out_the_left_out_groups_single_words(self):
        self.assertEqual(left_out_slurs(self.path), {"hund", "hunde", "hündin", "kater"})

    def test_writes_a_letter_form_pattern_for_each_slur(self):
        self.assertEqual(hatecheck_patterns(left_out_slurs(self.path)),
                         ["hund", "hunde", "hundin", "kater"])


if __name__ == "__main__":
    unittest.main()
