#!/usr/bin/env python3
"""Builds a typing plan of real human typos from the Aalto ITE typing dataset.

Uses phone typing sections where neither autocorrection nor the suggestion bar was used,
so the recorded input is what the typist's fingers produced (after any fixes they made
themselves). Each sentence's typed words become the letters to tap, tapped dead center
on their keys, and the sentence the typist was copying becomes the intended words.

Typists are split by ID so tuning and held-out plans never share a person.

Dataset: https://doi.org/10.5281/zenodo.12528163 (CC BY 4.0). Use
processed2020/english from the archive.
"""

import argparse
import csv
import json
import random
import re
import sys

WORD = re.compile(r"^[a-z']+$")
EDGE_PUNCTUATION = ".,!?;:\"()"


def words_of(text):
    """Lowercased words, or None if any token is not a plain letter word."""
    words = []
    for token in text.replace("’", "'").split():
        word = token.strip(EDGE_PUNCTUATION).lower()
        if not word:
            continue
        if not WORD.match(word) or not any(c.isalpha() for c in word):
            return None
        words.append(word)
    return words or None


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("english_dir", help="path to processed2020/english")
    parser.add_argument("output", help="typing plan JSON to write")
    parser.add_argument("--split", choices=["tune", "holdout"], required=True)
    parser.add_argument("--max-sentences", type=int, default=3000)
    parser.add_argument("--seed", type=int, default=1)
    args = parser.parse_args()
    csv.field_size_limit(sys.maxsize)

    with open(f"{args.english_dir}/participants_labeled.csv", newline="") as file:
        mobile_participants = {
            row["PARTICIPANT_ID"].split(".")[0]
            for row in csv.DictReader(file)
            if row["DEVICE"] == "mobile"
        }
    with open(f"{args.english_dir}/sentences.csv", newline="") as file:
        sentences = {row["SENTENCE_ID"]: row["SENTENCE"] for row in csv.DictReader(file)}

    planned = []
    with open(f"{args.english_dir}/test_sections_labeled.csv", newline="") as file:
        for row in csv.DictReader(file):
            participant = row["PARTICIPANT_ID"].split(".")[0]
            if participant not in mobile_participants:
                continue
            if (int(participant) % 5 == 0) != (args.split == "holdout"):
                continue
            if any(float(row[column] or 0) != 0 for column in ("AC", "PREDICTION")):
                continue
            intended = words_of(sentences.get(row["SENTENCE_ID"], ""))
            typed = words_of(row["USER_INPUT"])
            if not intended or not typed or len(intended) != len(typed):
                continue
            planned.append({
                "words": typed,
                "intended": intended,
                "taps": [[[0.0, 0.0] for c in word if c != "'"] for word in typed],
            })

    random.Random(args.seed).shuffle(planned)
    planned = planned[: args.max_sentences]
    with open(args.output, "w") as file:
        json.dump({"noiseInKeyPitches": 0.0, "seed": args.seed, "sentences": planned}, file)

    words = sum(len(s["words"]) for s in planned)
    typos = sum(t != i for s in planned for t, i in zip(s["words"], s["intended"]))
    print(f"{len(planned)} sentences, {words} words, {typos} typed differently from intended")


if __name__ == "__main__":
    main()
