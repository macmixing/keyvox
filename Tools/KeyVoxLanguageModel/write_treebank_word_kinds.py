"""Writes each word's most common lexical class as a Universal Dependencies treebank (CoNLL-U)
marks it, in the classes and format tag_word_kinds.swift writes for Apple's tagger: one
"word<TAB>class" line per word, lowercased as the keyboard reads it. For a language Apple's
tagger does not tag, such as Spanish, whose words it marks all as OtherWord.

A word written as one but split by the treebank into several, such as a preposition fused with
an article or a verb joined to its pronouns, takes its first part's class, as Apple's tagger
joins contractions. Ties go to the
class first in alphabetical order, as in tag_word_kinds.swift.
"""

import argparse
import unicodedata
from collections import Counter, defaultdict
from pathlib import Path

from normalize import is_word

# Universal POS tags in Apple's NLTag lexical classes; punctuation and symbols have none.
KINDS = {
    "NOUN": "Noun", "PROPN": "Noun", "VERB": "Verb", "AUX": "Verb", "ADJ": "Adjective",
    "ADV": "Adverb", "PRON": "Pronoun", "DET": "Determiner", "ADP": "Preposition",
    "CCONJ": "Conjunction", "SCONJ": "Conjunction", "PART": "Particle", "NUM": "Number",
    "INTJ": "Interjection", "X": "OtherWord",
}


def tokens(path: Path):
    """Each written token's form and its (first) part's universal POS tag."""
    with open(path, encoding="utf-8") as lines:
        joined_until = 0
        joined_form = None
        for line in lines:
            if not line.strip():
                # A blank line ends the sentence; the next one numbers its words from 1 again.
                joined_until = 0
                joined_form = None
                continue
            if line.startswith("#"):
                continue
            fields = line.rstrip("\n").split("\t")
            identifier, form, tag = fields[0], fields[1], fields[3]
            if "." in identifier:
                continue
            if "-" in identifier:
                first, last = identifier.split("-")
                joined_form, joined_until = form, int(last)
                continue
            position = int(identifier)
            if joined_form is not None:
                yield joined_form, tag
                joined_form = None
                continue
            if position <= joined_until:
                continue
            yield form, tag


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("output", type=Path)
    parser.add_argument("treebank", type=Path, nargs="+", help="CoNLL-U files")
    arguments = parser.parse_args()

    counts: defaultdict[str, Counter] = defaultdict(Counter)
    for path in arguments.treebank:
        for form, tag in tokens(path):
            word = unicodedata.normalize("NFC", form).replace("’", "'").lower()
            if tag in KINDS and is_word(word):
                counts[word][KINDS[tag]] += 1
    lines = [f"{word}\t{min(kinds, key=lambda kind: (-kinds[kind], kind))}\n" for word, kinds in sorted(counts.items())]
    arguments.output.write_text("".join(lines), encoding="utf-8")
    print(f"{len(lines)} words")


if __name__ == "__main__":
    main()
