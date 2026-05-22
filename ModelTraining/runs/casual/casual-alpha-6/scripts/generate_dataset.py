#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-6-continuation-money-negation-boundaries"
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

MONEY_DAY_AMOUNTS = [
    ("fifty", "$50"),
    ("one hundred", "$100"),
    ("a hundred", "$100"),
    ("forty-three", "$43"),
    ("forty three", "$43"),
    ("one hundred eighty", "$180"),
]

DAY_COUNTS = [
    ("three", "3"),
    ("seven", "7"),
]

STAR_RATING_COUNTS = [
    ("twelve", "12"),
]

PRICE_RATIO_PAIRS = [
    ("ten", "10", "one dollar", "$1"),
    ("two", "2", "one dollar", "$1"),
    ("four", "4", "one dollar", "$1"),
    ("five", "5", "one dollar", "$1"),
]

MONEY_MULTIPLIER_PAIRS = [
    ("fifty dollars", "$50"),
    ("fifty seven dollars", "$57"),
]

MULTIPLIER_COUNTS = [
    ("three", "3"),
]

SYMBOL_MULTIPLIER_PAIRS = [
    ("3", "50 dollars", "$50"),
    ("3", "57 dollars", "$57"),
]

NEGATED_MONEY_PAIRS = [
    ("five dollars", "$5", "three dollars", "$3"),
    ("three dollars", "$3", "five dollars", "$5"),
    ("twenty dollars", "$20", "five dollars", "$5"),
    ("twenty-five dollars", "$25", "twenty dollars", "$20"),
    ("twenty five dollars", "$25", "twenty dollars", "$20"),
    ("fifty dollars", "$50", "three dollars", "$3"),
]

MONEY_TIME_PAIRS = [
    ("twenty dollars", "$20", "three thirty", "3:30"),
    ("twenty-five dollars", "$25", "three thirty", "3:30"),
    ("twenty five dollars", "$25", "three thirty", "3:30"),
    ("twenty two dollars", "$22", "four forty five", "4:45"),
    ("twenty-seven dollars", "$27", "eleven fifteen", "11:15"),
    ("twenty seven dollars", "$27", "eleven fifteen", "11:15"),
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

    for amount_spoken, amount_digits in MONEY_DAY_AMOUNTS:
        for day_spoken, day_digits in DAY_COUNTS:
            add(
                examples,
                seen,
                "money_day_boundary",
                f"I would have spent {amount_spoken} dollars {day_spoken} days ago.",
                f"I would have spent {amount_digits} {day_digits} days ago.",
            )
            add(
                examples,
                seen,
                "money_day_boundary",
                f"It probably would have cost {amount_spoken} dollars {day_spoken} days ago.",
                f"It probably would have cost {amount_digits} {day_digits} days ago.",
            )

    for count_spoken, count_digits in STAR_RATING_COUNTS:
        add(
            examples,
            seen,
            "star_rating_boundary",
            f"I have like {count_spoken} five star ratings right now.",
            f"I have like {count_digits} 5-star ratings right now.",
        )

    for count_spoken, count_digits, price_phrase, price_digits in PRICE_RATIO_PAIRS:
        add(
            examples,
            seen,
            "price_ratio_boundary",
            f"I ended up getting {count_spoken} for {price_phrase}.",
            f"I ended up getting {count_digits} for {price_digits}.",
        )
        add(
            examples,
            seen,
            "price_ratio_boundary",
            f"Yeah, I got {count_spoken} for {price_phrase}.",
            f"Yeah, I got {count_digits} for {price_digits}.",
        )
        add(
            examples,
            seen,
            "price_ratio_boundary",
            f"That deal was {count_spoken} for {price_phrase}.",
            f"That deal was {count_digits} for {price_digits}.",
        )

    for money_spoken, money_digits in MONEY_MULTIPLIER_PAIRS:
        for count_spoken, count_digits in MULTIPLIER_COUNTS:
            add(
                examples,
                seen,
                "math_money_boundary",
                f"Yeah, that was what? {money_spoken.capitalize()} multiplied by {count_spoken}?",
                f"Yeah, that was what? {money_digits} multiplied by {count_digits}?",
            )
            add(
                examples,
                seen,
                "math_money_boundary",
                f"Yeah, that was {money_spoken} multiplied by {count_spoken}.",
                f"Yeah, that was {money_digits} multiplied by {count_digits}.",
            )

    for left_digits, right_spoken, right_digits in SYMBOL_MULTIPLIER_PAIRS:
        add(
            examples,
            seen,
            "math_money_boundary",
            f"Yeah, that was {left_digits} * {right_spoken}.",
            f"Yeah, that was {left_digits} * {right_digits}.",
        )
        add(
            examples,
            seen,
            "math_money_boundary",
            f"What yeah, that was {left_digits} * {right_spoken}.",
            f"What yeah, that was {left_digits} * {right_digits}.",
        )

    money_boundary_pairs = [
        (
            "I have like twelve five star ratings right now.",
            "I have like 12 5-star ratings right now.",
        ),
        (
            "I would have spent fifty dollars seven days ago.",
            "I would have spent $50 7 days ago.",
        ),
        (
            "I would have spent one hundred dollars seven days ago.",
            "I would have spent $100 7 days ago.",
        ),
        (
            "I would have spent a hundred dollars seven days ago.",
            "I would have spent $100 7 days ago.",
        ),
        (
            "Yeah, I would have spent one hundred dollars seven days ago.",
            "Yeah, I would have spent $100 7 days ago.",
        ),
        (
            "It would have been one hundred dollars seven days ago.",
            "It would have been $100 7 days ago.",
        ),
        (
            "I would have spent forty-three dollars seven days ago.",
            "I would have spent $43 7 days ago.",
        ),
        (
            "I ended up getting ten for one dollar.",
            "I ended up getting 10 for $1.",
        ),
        (
            "I got ten for one dollar.",
            "I got 10 for $1.",
        ),
        (
            "Yeah, I ended up getting ten for one dollar.",
            "Yeah, I ended up getting 10 for $1.",
        ),
        (
            "It probably would have cost fifty dollars three days ago.",
            "It probably would have cost $50 3 days ago.",
        ),
        (
            "Yeah, that was what? Fifty dollars multiplied by three?",
            "Yeah, that was what? $50 multiplied by 3?",
        ),
        (
            "Yeah, that was 3 * 50 dollars.",
            "Yeah, that was 3 * $50.",
        ),
        (
            "What yeah, that was 3 * 57 dollars.",
            "What yeah, that was 3 * $57.",
        ),
        (
            "Move the call to 11:30 and send the one hundred eighty dollar invoice.",
            "Move the call to 11:30 and send the $180 invoice.",
        ),
        (
            "Send the one hundred eighty dollar invoice.",
            "Send the $180 invoice.",
        ),
        (
            "Yeah, send the one hundred eighty dollar invoice.",
            "Yeah, send the $180 invoice.",
        ),
    ]
    for user, assistant in money_boundary_pairs:
        add(examples, seen, "money_boundary_regression", user, assistant)

    for first_spoken, first_digits, second_spoken, second_digits in NEGATED_MONEY_PAIRS:
        add(
            examples,
            seen,
            "money_negation_boundary",
            f"Tell John the concert ain't {first_spoken}, but it'll be {second_spoken}.",
            f"Tell John the concert ain't {first_digits}, but it'll be {second_digits}.",
        )
        add(
            examples,
            seen,
            "money_negation_boundary",
            f"Tell John the concert is {first_spoken}, not {second_spoken}.",
            f"Tell John the concert is {first_digits}, not {second_digits}.",
        )
        add(
            examples,
            seen,
            "money_negation_boundary",
            f"I'm pretty sure that's like {first_spoken}, not {second_spoken}.",
            f"I'm pretty sure that's like {first_digits}, not {second_digits}.",
        )
        add(
            examples,
            seen,
            "money_negation_boundary",
            f"The cover is {first_spoken} instead of {second_spoken}.",
            f"The cover is {first_digits} instead of {second_digits}.",
        )

    for money_spoken, money_digits, time_spoken, time_digits in MONEY_TIME_PAIRS:
        add(
            examples,
            seen,
            "money_time_boundary",
            f"Um I'm pretty sure that's like {money_spoken} and starts at {time_spoken}.",
            f"I'm pretty sure that's like {money_digits} and starts at {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_boundary",
            f"I'm pretty sure that's {money_spoken} and the show starts at {time_spoken}.",
            f"I'm pretty sure that's {money_digits} and the show starts at {time_digits}.",
        )
        add(
            examples,
            seen,
            "money_time_boundary",
            f"Yeah, tickets are {money_spoken} and doors open at {time_spoken}.",
            f"Yeah, tickets are {money_digits} and doors open at {time_digits}.",
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
        Example(
            "money_negation_boundary",
            "Tell John the concert is three dollars, not five dollars.",
            "Tell John the concert is $3, not $5.",
        ),
        Example(
            "money_time_boundary",
            "Um I'm pretty sure that's like twenty dollars and starts at three thirty.",
            "I'm pretty sure that's like $20 and starts at 3:30.",
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
        Example(
            "money_negation_boundary",
            "Tell John the concert ain't five dollars, but it'll be three dollars.",
            "Tell John the concert ain't $5, but it'll be $3.",
        ),
        Example(
            "money_time_boundary",
            "Um I'm pretty sure that's like twenty-five dollars and starts at three thirty.",
            "I'm pretty sure that's like $25 and starts at 3:30.",
        ),
    ]

    held_out = {example.user for example in valid + test}
    train = [example for example in examples if example.user not in held_out]

    write_split(DATA_DIR / "train.jsonl", train)
    write_split(DATA_DIR / "valid.jsonl", valid)
    write_split(DATA_DIR / "test.jsonl", test)

    manifest = {
        "version": "casual-alpha-6",
        "purpose": "continuation from casual-alpha-5 for money negation boundaries, shortened-output prevention, and money plus time boundary precision with casual voice guards",
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
