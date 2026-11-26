"""Splits the ITE autocorrection and prediction events by typist into calibration and
holdout sets, written to `<data_dir>/work/ite/<set>.tsv`.

Each line is test section, typed letters, intended word, then up to three previous words,
newest first; wrong autocorrections also end with the word the logged keyboard chose. One
typist in five, picked by a hash of the typist's ID, is held out."""

import argparse
import csv
import hashlib
import re
from collections import Counter
from pathlib import Path

from paths import DataPaths
from sources import ite_path
from words import edit_distance, valid_word

SET_NAMES = (
    "ac_success_calibration", "ac_success_holdout", "ac_harm_holdout",
    "prediction_success_holdout", "preserve_calibration", "preserve_holdout",
    "prediction_completion_holdout", "prediction_next_word_holdout",
)


def clean(text):
    return (text or "").replace("\x92", "'").replace("’", "'").strip()


def previous_words(current_input, typed):
    text = clean(current_input)
    if typed and text.casefold().endswith(typed.casefold()):
        text = text[:-len(typed)]
    words = re.findall(r"[A-Za-z]+(?:['’][A-Za-z]+)?", text)
    return [clean(word).casefold() for word in words[-3:]][::-1]


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("data_dir", type=Path)
    data_dir = parser.parse_args().data_dir
    paths = DataPaths(data_dir)

    participants = {}
    with ite_path(data_dir, "processed2020/english/test_sections_labeled.csv").open(
            newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            participants[row["TEST_SECTION_ID"]] = row["PARTICIPANT_ID"]

    def split_for(test_section_id):
        participant = participants.get(test_section_id, test_section_id)
        bucket = int(hashlib.sha256(participant.encode()).hexdigest()[:8], 16) % 5
        return "holdout" if bucket == 0 else "calibration"

    stats = Counter()
    outputs = {name: [] for name in SET_NAMES}

    with ite_path(data_dir, "ITE_words/ac_words_en.csv").open(
            newline="", encoding="utf-8", errors="replace") as source:
        for row in csv.DictReader(source):
            typed = clean(row["TYPED_WORD"]).casefold()
            corrected = clean(row["AC_WORD"]).casefold()
            intended = clean(row["ORIGINAL_WORD"]).casefold()
            if not (valid_word(typed) and valid_word(corrected) and valid_word(intended)):
                stats["ac_rejected_shape"] += 1
                continue
            previous = previous_words(row["CURRENT_INPUT"], typed)
            split = split_for(row["TEST_SECTION_ID"])
            record = (row["TEST_SECTION_ID"], typed, intended, *previous)
            if typed == intended:
                stats["ac_no_change"] += 1
                outputs[f"preserve_{split}"].append(record)
                continue
            if corrected == intended:
                stats[f"ac_success_{split}"] += 1
                outputs[f"ac_success_{split}"].append(record)
            elif split == "holdout":
                stats["ac_harm_holdout"] += 1
                outputs["ac_harm_holdout"].append(record + (corrected,))

    with ite_path(data_dir, "ITE_words/pred_words_en.csv").open(
            newline="", encoding="utf-8", errors="replace") as source:
        for row in csv.DictReader(source):
            typed = clean(row["TYPED_WORD"]).casefold()
            predicted = clean(row["PRED_WORD"]).casefold()
            intended = clean(row["ORIGINAL_WORD"]).casefold()
            if not (valid_word(typed) and valid_word(predicted) and valid_word(intended)):
                stats["pred_rejected_shape"] += 1
                continue
            if split_for(row["TEST_SECTION_ID"]) != "holdout":
                continue
            if predicted != intended:
                stats["pred_wrong_holdout"] += 1
                continue
            raw_current_input = (row["CURRENT_INPUT"] or "").replace("\x92", "'").replace("’", "'")
            current_input = clean(raw_current_input)
            is_completion = (
                not raw_current_input.endswith((" ", "\t", "\n"))
                and (predicted.startswith(typed)
                     or edit_distance(typed, predicted) <= max(1, len(predicted) // 3))
            )
            engine_typed = typed if is_completion else ""
            completed_tail = predicted if current_input.casefold().endswith(predicted) else ""
            previous = previous_words(current_input, completed_tail)
            record = (row["TEST_SECTION_ID"], engine_typed, intended, *previous)
            outputs["prediction_success_holdout"].append(record)
            outputs["prediction_completion_holdout" if is_completion
                    else "prediction_next_word_holdout"].append(record)
            stats["prediction_success_holdout"] += 1

    for name, records in outputs.items():
        path = paths.ite_split(name)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("w", encoding="utf-8", newline="") as target:
            for record in records:
                target.write("\t".join(record) + "\n")

    for key in sorted(stats):
        print(f"{key}={stats[key]}")
    for name, records in outputs.items():
        print(f"{name}: events={len(records)}")


if __name__ == "__main__":
    main()
