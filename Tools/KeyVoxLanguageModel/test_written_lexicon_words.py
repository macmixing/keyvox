"""Checks that a lexicon word the word list lacks joins the vocabulary only when the counts have
it at least as often as the median word-list word they have.

Run: python -m unittest test_written_lexicon_words"""

import tempfile
import unittest
from pathlib import Path

import numpy as np

from vocabulary.written_lexicon_words import written_lexicon_words


class WrittenLexiconWordsTest(unittest.TestCase):
    def test_lexicon_words_written_as_often_as_the_median_listed_word_join(self):
        counted = {"listed-1": 50, "listed-2": 20, "listed-3": 10, "common": 20, "rare": 19}
        with tempfile.TemporaryDirectory() as directory:
            data_dir = Path(directory)
            (data_dir / "vocabulary.txt").write_text("".join(word + "\n" for word in counted), encoding="utf-8")
            np.savez(data_dir / "counts.npz", word_counts=np.array(list(counted.values()), dtype=np.int64))
            added = written_lexicon_words(
                data_dir,
                word_list={"listed-1", "listed-2", "listed-3", "unwritten"},
                lexicon={"Common", "rare", "listed-1", "uncounted"},
            )
        self.assertEqual(added, {"common"})


if __name__ == "__main__":
    unittest.main()
