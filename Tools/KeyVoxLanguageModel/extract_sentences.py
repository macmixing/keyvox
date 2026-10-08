"""Reads each downloaded source and writes its English text as normalized sentences, one
per line with words separated by spaces, to `<data_dir>/sentences/<source>.txt`."""

import argparse
import bz2
import csv
import gzip
import json
import sys
from collections.abc import Iterator
from pathlib import Path

import pyarrow.compute as compute
import pyarrow.parquet as parquet

from names import capitalized_names, mentions_any
from normalize import sentences
from sources import SOURCES


def youtube_texts(directory: Path) -> Iterator[str]:
    """Transcripts recorded in English and transcribed in English, not translations."""
    for path in sorted(directory.glob("*.parquet")):
        table = parquet.read_table(
            path, columns=["text", "original_language", "transcription_language"]
        )
        english = table.filter(
            compute.and_(
                compute.equal(table["original_language"], "en"),
                compute.equal(table["transcription_language"], "en"),
            )
        )
        yield from (text for text in english["text"].to_pylist() if text)


def oasst2_texts(directory: Path) -> Iterator[str]:
    """English messages from prompters and assistants alike."""
    for path in sorted(directory.glob("*.jsonl.gz")):
        with gzip.open(path, "rt", encoding="utf-8") as lines:
            for line in lines:
                message = json.loads(line)
                if message.get("lang") == "en" and message.get("text"):
                    yield message["text"]


def tatoeba_texts(directory: Path) -> Iterator[str]:
    """English sentences that mention no name. Tatoeba reuses a few invented characters
    ("Tom" opens about one sentence in seven), which would otherwise teach the keyboard that
    sentences start with them."""
    texts = list(tatoeba_rows(directory))
    names = capitalized_names(texts)
    return (text for text in texts if not mentions_any(text, names))


def tatoeba_rows(directory: Path) -> Iterator[str]:
    """English sentences; each row is id, language, sentence."""
    csv.field_size_limit(sys.maxsize)
    for path in sorted(directory.glob("*.tsv.bz2")):
        with bz2.open(path, "rt", encoding="utf-8") as rows:
            for row in csv.reader(rows, delimiter="\t", quoting=csv.QUOTE_NONE):
                if len(row) >= 3 and row[1] == "eng":
                    yield row[2]


READERS = {
    "youtube-commons": youtube_texts,
    "oasst2": oasst2_texts,
    "tatoeba": tatoeba_texts,
}


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("data_dir", type=Path)
    arguments = parser.parse_args()

    output_directory = arguments.data_dir / "sentences"
    output_directory.mkdir(parents=True, exist_ok=True)
    for source in SOURCES:
        texts = READERS[source.name](arguments.data_dir / "sources" / source.name)
        sentence_count = 0
        word_count = 0
        with open(output_directory / f"{source.name}.txt", "w", encoding="utf-8") as output:
            for text in texts:
                for words in sentences(text):
                    output.write(" ".join(words))
                    output.write("\n")
                    sentence_count += 1
                    word_count += len(words)
        print(f"{source.name}: {sentence_count} sentences, {word_count} words", flush=True)


if __name__ == "__main__":
    main()
