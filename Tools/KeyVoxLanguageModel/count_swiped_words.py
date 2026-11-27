"""Counts the words a language's swipe dataset (`Language.swiped_words`) had people swipe, for
the swipe vocabulary (write_swipe_vocabulary.py), and writes them to
`<data_dir>/swiped_word_counts.tsv`.

Each record of the dataset's training split is one swipe of a word of a sentence, with the word
as the sentence writes it and its place among the sentence's words split at spaces. The word is
counted as written, without the punctuation around it, a curly
apostrophe read as a straight one, and, apart, the times it is in the middle of a sentence:
neither where a sentence or quotation can begin nor right after (`normalize.begins_written_run`),
so that its capitals are its own.

The file has a header row, then a row per spelling in code-point order: the spelling, how many
records swipe it, and how many of those are in the middle of a sentence. A language without a
swipe dataset gets the header alone."""

import argparse
import json
import re
from collections import Counter
from pathlib import Path

from languages import LANGUAGES, language_argument
from normalize import begins_written_run

OUTPUT_NAME = "swiped_word_counts.tsv"

_SURROUNDING_PUNCTUATION = re.compile(r"^\W+|\W+$")
_LEADING_PUNCTUATION = re.compile(r"^\W*")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    language = LANGUAGES[arguments.language]

    records: Counter[str] = Counter()
    in_the_middle: Counter[str] = Counter()
    if language.swiped_words:
        source = language.swiped_words
        for file in source.files:
            with open(arguments.data_dir / "sources" / source.name / file.name, encoding="utf-8") as lines:
                for line in lines:
                    record = json.loads(line)
                    word = record["word"].replace("’", "'")
                    spelling = _SURROUNDING_PUNCTUATION.sub("", word)
                    if not spelling:
                        continue
                    records[spelling] += 1
                    words_before = record["sentence"].split()[:record["word_idx"]]
                    before = " ".join(words_before) + " " + _LEADING_PUNCTUATION.match(word).group()
                    if not begins_written_run(before, language.text_rules):
                        in_the_middle[spelling] += 1
        print(f"{source.name}: {records.total()} swipes, {len(records)} spellings", flush=True)

    with open(arguments.data_dir / OUTPUT_NAME, "w", encoding="utf-8") as output:
        output.write("spelling\tswiped\tin the middle of a sentence\n")
        for spelling in sorted(records):
            output.write(f"{spelling}\t{records[spelling]}\t{in_the_middle[spelling]}\n")
    print(f"{arguments.data_dir / OUTPUT_NAME}: {len(records)} spellings")


if __name__ == "__main__":
    main()
