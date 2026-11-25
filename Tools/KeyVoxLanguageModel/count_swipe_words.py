"""Counts each source's words for the swipe vocabulary (write_swipe_vocabulary.py) and writes
them to `<data_dir>/swipe_word_counts.tsv`.

Each source's texts are the ones the language data reads (source_texts.py), so Tatoeba's
texts that mention its recurring invented characters are left out. Its words are read as the
context model reads them (normalize.py: letters with inner apostrophes, lowercased), after
taking out what is no prose (`normalize.prose`):
- HTML character references such as "&nbsp;" are decoded, so a reference's name is not
  counted as a word;
- Markdown code, fenced blocks and inline spans, is skipped: chat messages paste code,
  whose names and keywords are not words people type.

For each word, per source: how often it is written, and how often it is joined to other
letters or digits in one run of text without spaces ("https://www", "pre-order", "ipv6",
"__init__"), so that it is a piece of a longer token rather than a word on its own. In the
written sources, also how often it is written in lowercase and in each spelling with
capitals away from where a sentence or quotation can begin.

The file has a header row, then a row per word in code-point order: the word, then per
source its count and joined count, then its lowercase count and its spellings with capitals
(`spelling:count`, comma-separated, likeliest first) in the written sources."""

import argparse
from collections import Counter, defaultdict
from pathlib import Path

from languages import LANGUAGES, language_argument
from normalize import joined_words, prose, words, written_runs
from source_texts import source_texts
from write_capitalized_spellings import WRITTEN_SOURCES

OUTPUT_NAME = "swipe_word_counts.tsv"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    language_argument(parser)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()
    language = LANGUAGES[arguments.language]
    names = [use.source.name for use in language.sources]

    counts = {name: Counter() for name in names}
    joined = {name: Counter() for name in names}
    lowercase: Counter[str] = Counter()
    capitalized: defaultdict[str, Counter[str]] = defaultdict(Counter)
    for source, texts_read in source_texts(language, arguments.data_dir):
        name = source.name
        texts = 0
        for text in texts_read:
            texts += 1
            text = prose(text)
            counts[name].update(words(text))
            joined[name].update(joined_words(text))
            if name not in WRITTEN_SOURCES:
                continue
            for run in written_runs(text, language.text_rules):
                for word in run[1:]:
                    key = word.lower()
                    if word == key:
                        lowercase[key] += 1
                    else:
                        capitalized[key][word] += 1
        print(f"{name}: {texts} texts, {counts[name].total()} words, {len(counts[name])} distinct", flush=True)

    listed = sorted(set().union(*counts.values()))
    with open(arguments.data_dir / OUTPUT_NAME, "w", encoding="utf-8") as output:
        output.write("\t".join(["word", *(f"{name}{suffix}" for name in names for suffix in ("", " joined")),
                                "written lowercase", "written with capitals"]) + "\n")
        for word in listed:
            spellings = sorted(capitalized[word].items(), key=lambda item: (-item[1], item[0])) if word in capitalized else []
            output.write("\t".join([
                word,
                *(str(table[name][word]) for name in names for table in (counts, joined)),
                str(lowercase[word]),
                ",".join(f"{spelling}:{count}" for spelling, count in spellings),
            ]) + "\n")
    print(f"{arguments.data_dir / OUTPUT_NAME}: {len(listed)} words")


if __name__ == "__main__":
    main()
