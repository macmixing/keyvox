"""Reads an AOSP LatinIME word list (`<language>_wordlist.combined.gz`): its header line, then a
line per word as ` word=<word>,f=<frequency>,...`, each followed by its shortcuts. Entries
marked `not_a_word=true` are left out."""

import gzip
from collections.abc import Iterator
from pathlib import Path

_WORD_LINE = " word="


def latinime_words(path: Path) -> Iterator[str]:
    with gzip.open(path, "rt", encoding="utf-8") as lines:
        for line in lines:
            if not line.startswith(_WORD_LINE):
                continue
            fields = dict(field.partition("=")[::2] for field in line.strip().split(","))
            if fields.get("not_a_word") != "true" and fields["word"]:
                yield fields["word"]
