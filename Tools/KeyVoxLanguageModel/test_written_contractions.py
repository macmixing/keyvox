"""Checks that a contraction of a word-list word joins the vocabulary only when the written sources
write it at least as often as the median word-list word they write.

Run: python -m unittest test_written_contractions"""

import tempfile
import unittest
from pathlib import Path

from vocabulary.written_contractions import written_contractions


class WrittenContractionsTest(unittest.TestCase):
    def test_contractions_of_listed_words_written_as_often_as_the_median_listed_word_join(self):
        with tempfile.TemporaryDirectory() as directory:
            data_dir = Path(directory)
            (data_dir / "sentences").mkdir()
            (data_dir / "sentences" / "a.txt").write_text(
                "aa bb aa's bb's\naa cc aa's\nzz's aa\n", encoding="utf-8")
            (data_dir / "sentences" / "b.txt").write_text("bb aa's zz's\n", encoding="utf-8")
            added = written_contractions(data_dir, ("a", "b"), {"aa", "bb", "cc"})
        # The listed words are written 3, 2, and 1 times: a median of 2.
        self.assertEqual(added, {"aa's"})


if __name__ == "__main__":
    unittest.main()
