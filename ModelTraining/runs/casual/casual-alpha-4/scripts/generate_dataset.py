#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-4-continuation-spoken-years"
REPORT_DIR = ROOT / "reports"
SYSTEM_PROMPT = (
    MODEL_TRAINING_ROOT / "prompts" / "casual" / "casual_training_system.txt"
).read_text(encoding="utf-8").strip()


@dataclass(frozen=True)
class Example:
    category: str
    user: str
    assistant: str


def record(example: Example) -> dict:
    return {
        "category": example.category,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": example.user},
            {"role": "assistant", "content": example.assistant},
        ],
    }


def add(examples: list[Example], seen: set[str], category: str, user: str, assistant: str) -> None:
    if user in seen:
        return
    seen.add(user)
    examples.append(Example(category, user, assistant))


YEARS_2010S = [
    ("twenty ten", "2010"),
    ("twenty eleven", "2011"),
    ("twenty twelve", "2012"),
    ("twenty thirteen", "2013"),
    ("twenty fourteen", "2014"),
    ("twenty fifteen", "2015"),
    ("twenty sixteen", "2016"),
    ("twenty seventeen", "2017"),
    ("twenty eighteen", "2018"),
    ("twenty nineteen", "2019"),
]

YEARS_2020S = [
    ("twenty twenty", "2020"),
    ("twenty twenty one", "2021"),
    ("twenty twenty two", "2022"),
    ("twenty twenty three", "2023"),
    ("twenty twenty four", "2024"),
    ("twenty twenty five", "2025"),
    ("twenty twenty six", "2026"),
    ("twenty twenty seven", "2027"),
    ("twenty twenty eight", "2028"),
    ("twenty twenty nine", "2029"),
]

QUANTITIES = [
    ("twenty two", "22"),
    ("twenty five", "25"),
    ("twenty seven", "27"),
    ("twenty eight", "28"),
]


def build_examples() -> list[Example]:
    examples: list[Example] = []
    seen: set[str] = set()

    for spoken, digits in YEARS_2010S:
        add(
            examples,
            seen,
            "spoken_year_2010s",
            f"I can't believe we haven't done that since what, {spoken}?",
            f"I can't believe we haven't done that since what, {digits}?",
        )
        add(
            examples,
            seen,
            "spoken_year_2010s",
            f"I'm pretty sure that movie came out in {spoken}. What do you think?",
            f"I'm pretty sure that movie came out in {digits}. What do you think?",
        )

    for spoken, digits in YEARS_2020S:
        add(
            examples,
            seen,
            "spoken_year_2020s",
            f"The renewal is {spoken} and the total is five hundred dollars.",
            f"The renewal is {digits} and the total is $500.",
        )

    mixed_pairs = [
        ("twenty twelve", "2012", "twenty eighteen", "2018"),
        ("twenty thirteen", "2013", "twenty nineteen", "2019"),
        ("twenty fifteen", "2015", "twenty twenty four", "2024"),
        ("twenty sixteen", "2016", "twenty twenty eight", "2028"),
    ]
    for first_spoken, first_digits, second_spoken, second_digits in mixed_pairs:
        add(
            examples,
            seen,
            "spoken_year_mixed",
            f"It feels like we've been doing this since {first_spoken}, but it's only {second_spoken}.",
            f"It feels like we've been doing this since {first_digits}, but it's only {second_digits}.",
        )

    for spoken, digits in QUANTITIES:
        add(
            examples,
            seen,
            "quantity_guard",
            f"The team closed {spoken} tickets, and this should stay casual.",
            f"The team closed {digits} tickets, and this should stay casual.",
        )

    guard_pairs = [
        (
            "Um okay, like I tested the adapter for 20 minutes, and I ain't saying it's perfect.",
            "Okay, like I tested the adapter for 20 minutes, and I ain't saying it's perfect.",
        ),
        (
            "Sarah and me was trying a few weird cases.",
            "Sarah and me was trying a few weird cases.",
        ),
        (
            "What you be doing matters less than whether the words stay put.",
            "What you be doing matters less than whether the words stay put.",
        ),
        (
            "Why the fuck is this button still weird?",
            "Why the fuck is this button still weird?",
        ),
        (
            "Move the call to 11:30 and send the one hundred eighty dollar invoice.",
            "Move the call to 11:30 and send the $180 invoice.",
        ),
        (
            "I need groceries:\n\n1. Um apples\n2. Like bananas\n3. Uh grapes",
            "I need groceries:\n\n1. Apples\n2. Like bananas\n3. Grapes",
        ),
    ]
    for user, assistant in guard_pairs:
        add(examples, seen, "casual_voice_guard", user, assistant)

    random.Random(44).shuffle(examples)
    return examples


def write_split(path: Path, examples: list[Example]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for example in examples:
            handle.write(json.dumps(record(example), ensure_ascii=False) + "\n")


def main() -> int:
    examples = build_examples()
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    valid = [
        Example(
            "spoken_year_2010s",
            "I can't believe so much time has passed. I haven't seen you since like twenty twelve.",
            "I can't believe so much time has passed. I haven't seen you since like 2012.",
        ),
        Example(
            "spoken_year_2010s",
            "The audit started in twenty eighteen and wrapped up in twenty nineteen.",
            "The audit started in 2018 and wrapped up in 2019.",
        ),
        Example(
            "quantity_guard",
            "The team closed twenty two tickets and reopened twenty eight.",
            "The team closed 22 tickets and reopened 28.",
        ),
        Example(
            "casual_voice_guard",
            "I ain't changing the invoice from one hundred eighty dollars.",
            "I ain't changing the invoice from $180.",
        ),
    ]
    test = [
        Example(
            "spoken_year_mixed",
            "It feels like we've been doing this since twenty twelve, but it's only twenty eighteen.",
            "It feels like we've been doing this since 2012, but it's only 2018.",
        ),
        Example(
            "spoken_year_2010s",
            "I can't believe we haven't done that since what, twenty twelve?",
            "I can't believe we haven't done that since what, 2012?",
        ),
        Example(
            "quantity_guard",
            "Please order twenty five labels and twenty nine envelopes.",
            "Please order 25 labels and 29 envelopes.",
        ),
        Example(
            "casual_voice_guard",
            "Sarah and me was checking the list at three thirty.",
            "Sarah and me was checking the list at 3:30.",
        ),
    ]

    held_out = {example.user for example in valid + test}
    train = [example for example in examples if example.user not in held_out]

    write_split(DATA_DIR / "train.jsonl", train)
    write_split(DATA_DIR / "valid.jsonl", valid)
    write_split(DATA_DIR / "test.jsonl", test)

    manifest = {
        "version": "casual-alpha-4",
        "purpose": "continuation from casual-alpha-3 for spoken 2010s year precision with casual voice guards",
        "train_count": len(train),
        "valid_count": len(valid),
        "test_count": len(test),
        "categories": Counter(example.category for example in train + valid + test),
    }
    with (REPORT_DIR / "dataset_manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print(f"wrote {len(train)} train, {len(valid)} valid, {len(test)} test examples to {DATA_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
