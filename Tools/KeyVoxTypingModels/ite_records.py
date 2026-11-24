"""Reads the ITE event sets `split_ite_events.py` writes, and the other word sets the rankers
are trained and checked on, as records of typed letters, intended word, and previous words.

Records are also put into one of ten buckets by the sentence the typist was copying, so a
sentence's words never land on both sides of a training and test split."""

import csv
import hashlib
import re

from sources import ite_path
from words import WORD, clean, damerau_osa, edit_distance, valid_word

# Words people type on purpose that no dictionary spells this way; they must be left alone.
EXPRESSIVE = """
ugh ughhh ughhhh omg omgg omgosh wow woww wowww nooo noooo nopeee sooo soooo
yesss yessss pleeease pleaseee stooop stoppp ahhh ahhhh awww awwww hmmm hmmmmm
umm ummm uhhh huhhh heyyy hiiii hellooo byeee whaaat whyyy finallyyy literallyyy
reallyyy seriouslyyy absolutelyyy exactlyyy totallyyy definitelyyy fuck fuckkk
fucking fuckin shit shitt shitty damn damnn helll bitch asshole pissed pisseddd
sad sadder saddest angry furious anxious terrified scared heartbroken devastated
excited ecstatic joyful grateful relieved lonely overwhelmed exhausted hopeful
loving loved loveee miss misss sorry sorryyy congrats congratsggg lol loll lmao
lmfao rofl idk idkk tbh ngl imo imho btw brb ttyl rn af fr frr ikr yep yepper
nah nahh wanna gonna gotta kinda sorta lemme gimme dunno bc cuz cos tho thx pls
""".split()


def read_records(path, harm=False):
    records = []
    with path.open(encoding="utf-8") as source:
        for line in source:
            fields = line.rstrip("\n").split("\t")
            if len(fields) < 3:
                continue
            previous = fields[3:-1] if harm else fields[3:6]
            records.append({
                "participant": fields[0],
                "typed": clean(fields[1]),
                "expected": clean(fields[2]),
                "previous": [clean(word) for word in previous[:3]],
            })
    return records


def sample_calibration(records, denominator=5):
    selected = []
    for index, record in enumerate(records):
        identity = "\t".join((record["participant"], record["typed"],
                              record["expected"], *record["previous"], str(index)))
        bucket = int(hashlib.sha256(identity.encode()).hexdigest()[:8], 16) % denominator
        if bucket == 0:
            selected.append(record)
    return selected


def plausible_corrections(records):
    plausible = []
    for record in records:
        distance = damerau_osa(record["typed"], record["expected"])
        longest = max(len(record["typed"]), len(record["expected"]))
        if distance <= 4 and distance / max(1, longest) <= 0.5:
            plausible.append(record)
    return plausible


def correction_records(paths):
    """The ITE typos the correction ranker and action model learn from and are measured on: a
    fifth of the calibration typists' autocorrections and all of the held-out typists', the
    right ones and the wrong ones, each kept when its typed letters are a plausible typo of the
    intended word."""
    return plausible_corrections(
        sample_calibration(read_records(paths.ite_split("ac_success_calibration")))
        + read_records(paths.ite_split("ac_success_holdout"))
        + read_records(paths.ite_split("ac_harm_holdout"), harm=True))


def preserve_records(paths):
    """Every typist's words in the logged autocorrection events that were typed as meant."""
    return (read_records(paths.ite_split("preserve_calibration"))
            + read_records(paths.ite_split("preserve_holdout")))


def clean_sentence_records(data_dir):
    """Every word of the sentences ITE typists copied, typed correctly, with the words before it."""
    preserve = []
    next_word = []
    with ite_path(data_dir, "processed2020/english/sentences.csv").open(
            newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            tokens = [clean(token) for token in WORD.findall(row["SENTENCE"])]
            for index, token in enumerate(tokens):
                previous = list(reversed(tokens[max(0, index - 3):index]))
                preserve.append({"typed": token, "expected": token, "previous": previous})
                if previous:
                    next_word.append({"typed": "", "expected": token, "previous": previous})
    return preserve, next_word


def expressive_records():
    return [{"typed": word, "expected": word, "previous": ["i", "feel"]}
            for word in EXPRESSIVE]


def stable_bucket(value, modulus=10):
    return int(hashlib.sha256(str(value).encode()).hexdigest()[:8], 16) % modulus


def load_section_sentences(data_dir):
    result = {}
    with ite_path(data_dir, "processed2020/english/test_sections_labeled.csv").open(
            newline="", encoding="utf-8") as source:
        for row in csv.DictReader(source):
            result[row["TEST_SECTION_ID"]] = row["SENTENCE_ID"]
    return result


def record_bucket(record, section_sentences):
    section = record.get("participant", "")
    sentence = section_sentences.get(section)
    if sentence is None:
        identity = "\t".join((record["typed"], record["expected"], *record["previous"]))
        return stable_bucket(identity)
    return stable_bucket(sentence)


def annotate(records, section_sentences):
    result = []
    for record in records:
        copied = dict(record)
        copied["bucket"] = record_bucket(record, section_sentences)
        result.append(copied)
    return result


def completion_records(data_dir):
    """Every typist's accepted word completions: typed letters, the picked word, and the
    words before it."""
    records = []
    with ite_path(data_dir, "ITE_words/pred_words_en.csv").open(
            newline="", encoding="utf-8", errors="replace") as source:
        for row in csv.DictReader(source):
            typed = clean(row["TYPED_WORD"])
            predicted = clean(row["PRED_WORD"])
            intended = clean(row["ORIGINAL_WORD"])
            if not (valid_word(typed) and valid_word(predicted) and valid_word(intended)):
                continue
            if predicted != intended:
                continue
            raw_current_input = ((row["CURRENT_INPUT"] or "").replace("\x92", "'")
                                 .replace("’", "'"))
            is_completion = (
                not raw_current_input.endswith((" ", "\t", "\n"))
                and (predicted.startswith(typed)
                     or edit_distance(typed, predicted) <= max(1, len(predicted) // 3))
            )
            if not is_completion:
                continue
            current_input = clean(raw_current_input)
            completed_tail = predicted if current_input.casefold().endswith(predicted) else ""
            records.append({
                "participant": row["TEST_SECTION_ID"], "typed": typed,
                "expected": intended,
                "previous": previous_words(current_input, completed_tail),
            })
    return records


def previous_words(current_input, completed_tail):
    text = clean(current_input)
    if completed_tail and text.casefold().endswith(completed_tail.casefold()):
        text = text[:-len(completed_tail)]
    words = re.findall(r"[A-Za-z]+(?:['’][A-Za-z]+)?", text)
    return [clean(word) for word in words[-3:]][::-1]
