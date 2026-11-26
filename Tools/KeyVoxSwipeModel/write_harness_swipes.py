"""Writes one swipe.futo.org first-run split as the typing harness reads it, each swipe with
the words swiped before it in its recording session:

    {"word": ..., "previous": [newest first], "w": canvas width, "h": canvas height,
     "points": [[t ms, x, y], ...]}  (x and y normalized to the canvas)

A session's words are put in recording order by their record number, merged across all
three splits, since a session's sentence can span them. Record numbers are one counter
shared by every session, so sessions recorded at the same time interleave and a missing
number says nothing about the session; a word the person skipped leaves no record. A
swipe's previous words are the session's records right before it in that order, back to a
word that ends a sentence, at most `PREVIOUS_WORDS`. Each previous word keeps only its word
characters, apostrophes, and inner hyphens. Records without points are left out.

    python write_harness_swipes.py <data-dir> dev <out.jsonl>
    python write_harness_swipes.py <data-dir> test <out.jsonl>"""

import argparse
import json
import re
from collections import defaultdict
from pathlib import Path

FUTO = Path("sources/futo-swipe")
SPLITS = ("train.jsonl", "dev.jsonl", "test.jsonl")
PREVIOUS_WORDS = 3
# The marks the recorded sentences end with.
SENTENCE_ENDS = (".", "!", "?")
# Each record begins with its number, session, and word; reading only that much of every
# line keeps merging the splits fast.
_HEAD = re.compile(r'"id":(\d+),"session":"([^"]+)".*?"word":"((?:[^"\\]|\\.)*)"')
_HEAD_CHARACTERS = 600
_NOT_WORD = re.compile(r"[^\w'’-]")


def clean(word: str) -> str:
    return _NOT_WORD.sub("", word).strip("-")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("split", choices=("dev", "test"))
    parser.add_argument("output", type=Path)
    arguments = parser.parse_args()

    sessions: dict[str, dict[int, str]] = defaultdict(dict)
    for name in SPLITS:
        with open(arguments.data_dir / FUTO / name) as file:
            for line in file:
                match = _HEAD.search(line, 0, _HEAD_CHARACTERS)
                if match:
                    sessions[match.group(2)][int(match.group(1))] = json.loads(f'"{match.group(3)}"')

    order = {session: sorted(words) for session, words in sessions.items()}
    position = {session: {number: index for index, number in enumerate(numbers)} for session, numbers in order.items()}

    count = 0
    with open(arguments.data_dir / FUTO / f"{arguments.split}.jsonl") as file, open(arguments.output, "w") as output:
        for line in file:
            record = json.loads(line)
            if not isinstance(record["data"], list) or not record["data"]:
                continue
            words, numbers = sessions[record["session"]], order[record["session"]]
            previous = []
            index = position[record["session"]][record["id"]] - 1
            while index >= 0 and not words[numbers[index]].endswith(SENTENCE_ENDS) and len(previous) < PREVIOUS_WORDS:
                previous.append(clean(words[numbers[index]]))
                index -= 1
            output.write(json.dumps({
                "word": record["word"], "previous": [word for word in previous if word],
                "w": record["canvas_width"], "h": record["canvas_height"],
                "points": [[point["t"], point["x"], point["y"]] for point in record["data"]],
            }) + "\n")
            count += 1
    print(f"wrote {arguments.output} ({count} swipes)")


if __name__ == "__main__":
    main()
