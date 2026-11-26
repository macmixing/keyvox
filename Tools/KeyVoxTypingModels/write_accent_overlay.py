"""Writes the accent overlay the keyboard bundles, `<data_dir>/built/accent_overlay.bin`:
for each accented word the dictionary lacks, the plain letters that type it.

KVAC0001 format: magic and entry count, then per entry the byte lengths of the plain
letters and of the word, the word's probability, the plain letters, and the word, sorted by
plain letters, likeliest word first."""

import argparse
import struct
import unicodedata
from pathlib import Path

from paths import DataPaths

MAGIC = b"KVAC0001"
HEADER = struct.Struct("<8sI")
ENTRY = struct.Struct("<BBB")


def folded(word):
    decomposed = unicodedata.normalize("NFKD", word)
    return "".join(character for character in decomposed
                   if not unicodedata.combining(character)).casefold()


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    paths = DataPaths(parser.parse_args().data_dir)

    entries = []
    for line in paths.accent_unigrams.read_text(encoding="utf-8").splitlines():
        word, probability = line.split("\t")
        key = folded(word)
        if not key.isascii() or key == word:
            continue
        entries.append((key, word, int(probability)))
    entries.sort(key=lambda item: (item[0], -item[2], item[1]))

    paths.built.mkdir(parents=True, exist_ok=True)
    with paths.accent_overlay.open("wb") as target:
        target.write(HEADER.pack(MAGIC, len(entries)))
        for key, word, probability in entries:
            key_bytes = key.encode("utf-8")
            word_bytes = word.encode("utf-8")
            if len(key_bytes) > 255 or len(word_bytes) > 255:
                raise ValueError("accent overlay entry exceeds compact format")
            target.write(ENTRY.pack(len(key_bytes), len(word_bytes), probability))
            target.write(key_bytes)
            target.write(word_bytes)
    print(f"{paths.accent_overlay}: {len(entries)} entries")


if __name__ == "__main__":
    main()
