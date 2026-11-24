"""Checks that write_treebank_word_kinds.py reads every word of a sentence that follows one with
a word the treebank splits into parts. Run with `python -m unittest test_write_treebank_word_kinds`."""

import tempfile
import unittest
from pathlib import Path

from write_treebank_word_kinds import tokens

# Two CoNLL-U sentences: the first ends with a word split into parts 2-3, the second has three
# words of its own.
_TREEBANK = (
    "# sent_id = 1\n"
    "1\tVoy\tir\tVERB\t_\t_\t0\troot\t_\t_\n"
    "2-3\tal\t_\t_\t_\t_\t_\t_\t_\t_\n"
    "2\ta\ta\tADP\t_\t_\t4\tcase\t_\t_\n"
    "3\tel\tel\tDET\t_\t_\t4\tdet\t_\t_\n"
    "4\tcine\tcine\tNOUN\t_\t_\t1\tobl\t_\t_\n"
    "\n"
    "# sent_id = 2\n"
    "1\tElla\tél\tPRON\t_\t_\t2\tnsubj\t_\t_\n"
    "2\tcanta\tcantar\tVERB\t_\t_\t0\troot\t_\t_\n"
    "3\tbien\tbien\tADV\t_\t_\t2\tadvmod\t_\t_\n"
    "\n"
)


class TreebankTokensTests(unittest.TestCase):
    def test_keeps_every_word_after_a_sentence_with_a_split_word(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "treebank.conllu"
            path.write_text(_TREEBANK, encoding="utf-8")
            read = list(tokens(path))
        self.assertEqual(read, [
            ("Voy", "VERB"), ("al", "ADP"), ("cine", "NOUN"),
            ("Ella", "PRON"), ("canta", "VERB"), ("bien", "ADV"),
        ])


if __name__ == "__main__":
    unittest.main()
