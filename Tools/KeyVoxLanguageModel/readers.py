"""Reads each source's files as the texts written or spoken in the source's language, one
text at a time: a transcript, a video's captions, a message, a sentence, or a speech.
`READERS` names each reader as `Source.reader` does; every reader takes the source's files
and the language code its rows are marked with."""

import bz2
import csv
import gzip
import json
import re
import sys
import xml.etree.ElementTree as ElementTree
from collections.abc import Iterator
from pathlib import Path

import compression.zstd as zstd
import pyarrow.compute as compute
import pyarrow.parquet as parquet

# A longer chat turn is mostly a pasted document rather than something the user wrote.
WILDCHAT_MAXIMUM_WORDS = 50
_TEI = "{http://www.tei-c.org/ns/1.0}"
# In a text message, emoticons and the stand-ins for anonymized names and numbers.
_SMS_SKIPPED = {f"{_TEI}distinct", f"{_TEI}fs"}
# A Bundestag speech marks where an interjection or applause was, in parentheses.
_PARENTHESIZED = re.compile(r"\([^()]*\)")
# The Bundestag's record is written in the reformed German spelling from this year on; before
# it, in the spelling the 1996 reform replaced (measured by year in Open Discourse 4.0).
BUNDESTAG_FIRST_YEAR = 2000


def youtube_texts(paths: list[Path], code: str) -> Iterator[str]:
    """Transcripts recorded in the language and transcribed in it, not translations."""
    for path in sorted(paths):
        table = parquet.read_table(
            path, columns=["text", "original_language", "transcription_language"]
        )
        native = table.filter(
            compute.and_(
                compute.equal(table["original_language"], code),
                compute.equal(table["transcription_language"], code),
            )
        )
        yield from (text for text in native["text"].to_pylist() if text)


def _json_lines(path: Path) -> Iterator[dict]:
    opened = zstd.open(path, "rt", encoding="utf-8") if path.suffix == ".zst" else open(path, encoding="utf-8")
    with opened as lines:
        for line in lines:
            yield json.loads(line)


def prepared_youtube_texts(paths: list[Path], code: str) -> Iterator[str]:
    """Transcripts already kept to the videos spoken and transcribed in the language."""
    for path in sorted(paths):
        yield from (record["text"] for record in _json_lines(path) if record.get("text"))


def yodas2_texts(paths: list[Path], code: str) -> Iterator[str]:
    """Each video's captions in order, joined by spaces: a caption ends where the screen
    changes, not where a sentence does."""
    for path in sorted(paths):
        for record in _json_lines(path):
            text = " ".join(caption for caption in record["text"].values() if caption)
            if text:
                yield text


def oasst2_texts(paths: list[Path], code: str) -> Iterator[str]:
    """Messages in the language from prompters and assistants alike."""
    for path in sorted(paths):
        with gzip.open(path, "rt", encoding="utf-8") as lines:
            for line in lines:
                message = json.loads(line)
                if message.get("lang") == code and message.get("text"):
                    yield message["text"]


def tatoeba_rows(paths: list[Path], code: str) -> Iterator[str]:
    """Sentences in the language; each row is id, language, sentence."""
    csv.field_size_limit(sys.maxsize)
    for path in sorted(paths):
        with bz2.open(path, "rt", encoding="utf-8") as rows:
            for row in csv.reader(rows, delimiter="\t", quoting=csv.QUOTE_NONE):
                if len(row) >= 3 and row[1] == code:
                    yield row[2]


def wildchat_texts(paths: list[Path], code: str) -> Iterator[str]:
    """What users wrote to the assistant, up to `WILDCHAT_MAXIMUM_WORDS` words a turn."""
    for path in sorted(paths):
        for turn in _json_lines(path):
            if turn.get("text") and turn["word_count"] <= WILDCHAT_MAXIMUM_WORDS:
                yield turn["text"]


def _message_text(element) -> str:
    parts = [element.text or ""]
    for child in element:
        if child.tag not in _SMS_SKIPPED:
            parts.append(_message_text(child))
        parts.append(child.tail or "")
    return "".join(parts)


def sms_texts(paths: list[Path], code: str) -> Iterator[str]:
    """Each text message's words, with its line wraps in the corpus file joined, and without
    its emoticons or the stand-ins for what was anonymized."""
    for path in sorted(paths):
        for _, element in ElementTree.iterparse(path):
            if element.tag == f"{_TEI}post":
                text = " ".join(" ".join(_message_text(paragraph).split()) for paragraph in element.iter(f"{_TEI}p"))
                if text:
                    yield text
                element.clear()


def bundestag_texts(paths: list[Path], code: str) -> Iterator[str]:
    """Each speech given from `BUNDESTAG_FIRST_YEAR` on, with the line wraps of the printed record
    joined and without the parenthesized notes of interjections and applause."""
    for path in sorted(paths):
        for record in _json_lines(path):
            if int(record["date"][:4]) < BUNDESTAG_FIRST_YEAR:
                continue
            text = " ".join(_PARENTHESIZED.sub(" ", record["text"] or "").split())
            if text:
                yield text


READERS = {
    "youtube-commons-parquet": youtube_texts,
    "youtube-commons-jsonl": prepared_youtube_texts,
    "yodas2": yodas2_texts,
    "oasst2": oasst2_texts,
    "tatoeba": tatoeba_rows,
    "wildchat": wildchat_texts,
    "88milsms": sms_texts,
    "open-discourse": bundestag_texts,
}


def source_paths(data_dir: Path, source) -> list[Path]:
    return [data_dir / "sources" / source.name / file.name for file in source.files]


def read_source(data_dir: Path, source) -> Iterator[str]:
    return READERS[source.reader](source_paths(data_dir, source), source.code)
