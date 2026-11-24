"""Reads the written English text the typing models count words in: Tatoeba sentences,
OASST1 messages, and the ITE sentences typists copied, which the counts leave out."""

import bz2
import csv

import pyarrow.parquet as pq

# An OASST1 message counts five times as much as a Tatoeba sentence.
OASST1_WEIGHT = 5


def tatoeba_sentences(path):
    """The text of each sentence; each line is id, language, sentence."""
    with bz2.open(path, "rt", encoding="utf-8") as source:
        for line in source:
            fields = line.rstrip("\n").split("\t")
            if len(fields) >= 3:
                yield fields[2]


def oasst1_messages(path):
    """English messages that were kept, written by people, and not rejected in review."""
    table = pq.read_table(path, columns=["text", "lang", "deleted", "synthetic", "review_result"])
    for row in table.to_pylist():
        if row["lang"] != "en" or row["deleted"]:
            continue
        if row["synthetic"] is True or row["review_result"] is False:
            continue
        yield row["text"] or ""


def ite_sentences(path):
    """The sentences ITE typists were asked to copy."""
    with open(path, newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            yield row["SENTENCE"]
