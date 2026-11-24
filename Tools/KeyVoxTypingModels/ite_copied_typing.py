"""The words ITE phone typists typed with autocorrection and suggestions off, each with the word
they were copying, so what their fingers produced, after the fixes they made themselves, can be
measured.

Sections are picked as `Tools/KeyVoxTypingHarness/Scripts/ite_typo_plan.py` picks them for the
harness's ITE plan: phone typists, neither autocorrection nor a suggestion used, and as many
typed words as copied ones. Only the typists that plan never holds out are read, those whose ID
is not a multiple of five, so nothing measured here comes from the people the harness scores
on."""

import csv
import re
import sys

from sources import ite_path

PLAN_WORD = re.compile(r"^[a-z']+$")
EDGE_PUNCTUATION = ".,!?;:\"()"


def plan_words(text):
    """Lowercased words, or None if any token is not a plain letter word, as the plan reads
    them."""
    words = []
    for token in text.replace("’", "'").split():
        word = token.strip(EDGE_PUNCTUATION).lower()
        if not word:
            continue
        if not PLAN_WORD.match(word) or not any(character.isalpha() for character in word):
            return None
        words.append(word)
    return words or None


def is_tuning_typist(participant):
    return int(participant) % 5 != 0


def copied_sentences(data_dir):
    """Each picked section's (participant, intended words, typed words)."""
    csv.field_size_limit(sys.maxsize)
    english = "processed2020/english"
    with ite_path(data_dir, f"{english}/participants_labeled.csv").open(
            newline="", encoding="utf-8") as source:
        phone_typists = {row["PARTICIPANT_ID"].split(".")[0] for row in csv.DictReader(source)
                         if row["DEVICE"] == "mobile"}
    with ite_path(data_dir, f"{english}/sentences.csv").open(newline="", encoding="utf-8") as source:
        sentences = {row["SENTENCE_ID"]: row["SENTENCE"] for row in csv.DictReader(source)}
    with ite_path(data_dir, f"{english}/test_sections_labeled.csv").open(
            newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            participant = row["PARTICIPANT_ID"].split(".")[0]
            if participant not in phone_typists or not is_tuning_typist(participant):
                continue
            if any(float(row[column] or 0) != 0 for column in ("AC", "PREDICTION")):
                continue
            intended = plan_words(sentences.get(row["SENTENCE_ID"], ""))
            typed = plan_words(row["USER_INPUT"])
            if intended and typed and len(intended) == len(typed):
                yield participant, intended, typed


def section_participants(data_dir):
    """Each test section's typist."""
    with ite_path(data_dir, "processed2020/english/test_sections_labeled.csv").open(
            newline="", encoding="utf-8") as source:
        return {row["TEST_SECTION_ID"]: row["PARTICIPANT_ID"].split(".")[0]
                for row in csv.DictReader(source)}
