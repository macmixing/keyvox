"""Checks the text rules a language's language.json adds: German reads its keyboard's apostrophe
"‘" between letters as an apostrophe and a period right after a digit as an ordinal number's,
while English reads its text as its bundled data was built.

Run: python -m unittest test_normalize"""

import unittest

from languages import LANGUAGES
from normalize import DEFAULT_RULES, sentences, sentences_with_endings

TEXT = "Am 3. Juli geht‘s los. ‚So‘ sagt er. Bis 3... Ja."


class TextRulesTest(unittest.TestCase):
    def test_german_reads_its_apostrophe_and_ordinal_periods(self):
        rules = LANGUAGES["de"].text_rules
        self.assertEqual(
            list(sentences(TEXT, rules)),
            [["am", "juli", "geht's", "los"], ["so", "sagt", "er"], ["bis"], ["ja"]],
        )
        self.assertEqual(
            list(sentences_with_endings(TEXT, rules)),
            [(["am", "juli", "geht's", "los"], "."), (["so", "sagt", "er"], "."), (["bis", "ja"], ".")],
        )

    def test_english_reads_as_its_bundled_data_was_built(self):
        self.assertEqual(LANGUAGES["en"].text_rules, DEFAULT_RULES)
        self.assertEqual(
            list(sentences(TEXT, LANGUAGES["en"].text_rules)),
            [["am"], ["juli", "geht", "s", "los"], ["so", "sagt", "er"], ["bis"], ["ja"]],
        )


if __name__ == "__main__":
    unittest.main()
