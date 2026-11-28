"""Writes swipe.futo.org swipes as the typing harness reads it, each swipe with the words
swiped before it: one first-run split, or the fifth run's one-finger swipes of one language on
one layout.

    {"word": ..., "previous": [newest first], "w": canvas width, "h": canvas height,
     "points": [[t ms, x, y], ...]}  (x and y normalized to the canvas)

The records of all three splits are read, and a session's words are put in recording order
by their record number. Record numbers are one counter shared by every session, so sessions
recorded at the same time interleave and a missing number says nothing about the session; a
word the person skipped leaves no record. A swipe's previous words are the session's records
right before it in that order, back to a word that ends a sentence, at most
`PREVIOUS_WORDS`. Each previous word keeps only its word characters, apostrophes, and inner
hyphens. Records without points are left out.

The fifth run's records name their sentence and the word's place in it, so a swipe's previous
words are the sentence's words before it, by the same rules. Its swipes are kept as
`prepare_swipes.py` keeps the run's English ones: one finger, with a scored distance at most the
first run's training distances' `EXTRA_DISTANCE_PERCENTILE` percentile. With `--half`, only the
swipes of half the recording sessions: `tune` the sessions whose SHA-256 of their name begins
with an even byte, `test` the rest, so no person's swipes are in both.

    python write_harness_swipes.py <data-dir> dev <out.jsonl>
    python write_harness_swipes.py <data-dir> test <out.jsonl>
    python write_harness_swipes.py <data-dir> swipe-5 <out.jsonl> --language de --layout german [--half tune]"""

import argparse
import hashlib
import json
import re
from collections import defaultdict
from pathlib import Path

import numpy as np

from prepare_swipes import EXTRA_DISTANCE_PERCENTILE, UNSCORED_DISTANCE

FUTO = Path("sources/futo-swipe")
FIFTH_RUN = "swipe-5/swipe5.jsonl"
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


def harness_line(record: dict, previous: list[str]) -> str:
    return json.dumps({
        "word": record["word"], "previous": [word for word in previous if word],
        "w": record["canvas_width"], "h": record["canvas_height"],
        "points": [[point["t"], point["x"], point["y"]] for point in record["data"]],
    }) + "\n"


def session_half(session: str) -> str:
    return "tune" if hashlib.sha256(session.encode()).digest()[0] % 2 == 0 else "test"


def write_fifth_run(data_dir: Path, language: str, layout: str, half: str | None, output: Path) -> None:
    distances = np.load(data_dir / "prepared" / "train.npz")["distance"]
    limit = float(np.percentile(distances[distances < UNSCORED_DISTANCE], EXTRA_DISTANCE_PERCENTILE))
    count = 0
    with open(data_dir / FUTO / FIFTH_RUN) as file, open(output, "w") as lines:
        for line in file:
            record = json.loads(line)
            if (record.get("language") != language or record.get("layout") != layout
                    or not isinstance(record["data"], list) or not record["data"]
                    or float(record.get("distance", UNSCORED_DISTANCE)) > limit
                    or (half is not None and session_half(record["session"]) != half)):
                continue
            before = record["sentence"].split()[:record["word_idx"]]
            previous = []
            for word in reversed(before):
                if word.endswith(SENTENCE_ENDS) or len(previous) == PREVIOUS_WORDS:
                    break
                previous.append(clean(word))
            lines.write(harness_line(record, previous))
            count += 1
    print(f"wrote {output} ({count} swipes, distance at most {limit:.1f})")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("data_dir", type=Path)
    parser.add_argument("split", choices=("dev", "test", "swipe-5"))
    parser.add_argument("output", type=Path)
    parser.add_argument("--language", help="swipe-5: the records' language, such as de")
    parser.add_argument("--layout", help="swipe-5: the records' layout, such as german")
    parser.add_argument("--half", choices=("tune", "test"), help="swipe-5: only half the sessions")
    arguments = parser.parse_args()
    if arguments.split == "swipe-5":
        if not arguments.language or not arguments.layout:
            parser.error("swipe-5 needs --language and --layout")
        write_fifth_run(arguments.data_dir, arguments.language, arguments.layout, arguments.half, arguments.output)
        return

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
            output.write(harness_line(record, previous))
            count += 1
    print(f"wrote {arguments.output} ({count} swipes)")


if __name__ == "__main__":
    main()
