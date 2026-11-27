"""Writes the accented words the dictionary lacks, such as loanwords spelled with their
accents, with a probability from how often Tatoeba and OASST1 use them, to
`<data_dir>/work/accent_unigrams.tsv`.

For English, the words are SCOWL size-60 words of every spelling that contain a letter outside
ASCII. Any other language's dictionary holds its words with their accents, and LatinIME finds them
from their plain letters, so the file is empty, and so is the overlay made from it."""

import argparse
import math
import unicodedata
from collections import Counter
from pathlib import Path

import regex

from paths import DataPaths
from sources import oasst1_path, tatoeba_path
from text_sources import OASST1_WEIGHT, oasst1_messages, tatoeba_sentences
from typing_languages import add_language_arguments, language_from

TOKEN = regex.compile(r"\p{L}+(?:['’]\p{L}+)?")
ENCODING_SCALER = 8.58923700372


def normalize(word):
    return unicodedata.normalize("NFC", word.replace("’", "'")).casefold()


def tokenize(text):
    return [normalize(token) for token in TOKEN.findall(text or "")]


def encode_probability(raw_probability):
    if raw_probability <= 0:
        return 0
    return max(1, min(255, round(255 + math.log2(raw_probability) * ENCODING_SCALER)))


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    add_language_arguments(parser)
    arguments = parser.parse_args()
    data_dir = arguments.data_dir
    paths = DataPaths(data_dir)
    if not language_from(arguments).uses_english_text:
        paths.accent_unigrams.write_text("", encoding="utf-8")
        print(f"{paths.accent_unigrams}: no words, as the dictionary holds the accented ones")
        return

    accented = {
        normalize(word) for word in paths.accented_words.read_text(encoding="utf-8").splitlines()
        if any(ord(character) > 127 for character in word)
    }
    counts = Counter()
    token_count = 0

    def observe(tokens, weight=1):
        nonlocal token_count
        token_count += len(tokens) * weight
        for token in tokens:
            if token in accented:
                counts[token] += weight

    for sentence in tatoeba_sentences(tatoeba_path(data_dir)):
        observe(tokenize(sentence))
    for message in oasst1_messages(oasst1_path(data_dir)):
        observe(tokenize(message), OASST1_WEIGHT)

    dictionary_words = {line.split("\t", 1)[0] for line in
                        paths.dictionary_unigrams.read_text(encoding="utf-8").splitlines()}
    denominator = token_count + len(dictionary_words) + len(accented)
    added = [(word, encode_probability((counts[word] + 1) / denominator))
             for word in sorted(accented) if word not in dictionary_words]
    with paths.accent_unigrams.open("w", encoding="utf-8") as target:
        for word, probability in added:
            target.write(f"{word}\t{probability}\n")
    print(f"accented_scowl={len(accented)} added={len(added)} corpus_tokens={token_count}")


if __name__ == "__main__":
    main()
