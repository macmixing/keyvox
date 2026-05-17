#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "polished" / "alpha-024-continuation-age-compounds"
REPORT_DIR = ROOT / "reports"
SYSTEM_PROMPT = (
    MODEL_TRAINING_ROOT / "prompts" / "polished" / "polished_runtime_short.txt"
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
    ("twenty one", "21"),
    ("twenty two", "22"),
    ("twenty three", "23"),
    ("twenty four", "24"),
    ("twenty five", "25"),
    ("twenty six", "26"),
    ("twenty seven", "27"),
    ("twenty eight", "28"),
    ("twenty nine", "29"),
]

TEEN_AGE_COMPOUNDS = [
    ("thirteen", "13"),
    ("fourteen", "14"),
    ("fifteen", "15"),
    ("sixteen", "16"),
    ("seventeen", "17"),
    ("eighteen", "18"),
    ("nineteen", "19"),
]


def build_examples() -> list[Example]:
    examples: list[Example] = []
    seen: set[str] = set()

    for spoken, digits in YEARS_2010S:
        add(
            examples,
            seen,
            "spoken_year_2010s",
            f"I am pretty sure that movie came out in {spoken}. What do you think?",
            f"I am pretty sure that movie came out in {digits}. What do you think?",
        )
        add(
            examples,
            seen,
            "spoken_year_2010s",
            f"I have not seen you since {spoken}.",
            f"I have not seen you since {digits}.",
        )
        add(
            examples,
            seen,
            "spoken_year_2010s",
            f"Please clean this up: um the contract started in {spoken}, and the renewal came later.",
            f"Please clean this up: the contract started in {digits}, and the renewal came later.",
        )

    for spoken, digits in YEARS_2020S:
        add(
            examples,
            seen,
            "spoken_year_2020s",
            f"The customer paid for the plan in {spoken}.",
            f"The customer paid for the plan in {digits}.",
        )
        add(
            examples,
            seen,
            "spoken_year_2020s",
            f"Please mention that the report covers {spoken}, not the year before.",
            f"Please mention that the report covers {digits}, not the year before.",
        )

    for (first_spoken, first_digits), (second_spoken, second_digits) in zip(YEARS_2010S, YEARS_2010S[1:]):
        add(
            examples,
            seen,
            "spoken_year_sequence",
            f"It feels like we have been doing this since {first_spoken}, but it only became official in {second_spoken}.",
            f"It feels like we have been doing this since {first_digits}, but it only became official in {second_digits}.",
        )

    year_sweep_spoken = ", ".join(spoken for spoken, _ in YEARS_2010S[:-1])
    year_sweep_digits = ", ".join(digits for _, digits in YEARS_2010S[:-1])
    add(
        examples,
        seen,
        "spoken_year_sweep",
        f"The archive includes {year_sweep_spoken}, and {YEARS_2010S[-1][0]}.",
        f"The archive includes {year_sweep_digits}, and {YEARS_2010S[-1][1]}.",
    )
    add(
        examples,
        seen,
        "spoken_year_sweep",
        "Please list the supported launch years as twenty ten, twenty eleven, twenty twelve, twenty thirteen, twenty fourteen, twenty fifteen, twenty sixteen, twenty seventeen, twenty eighteen, and twenty nineteen.",
        "Please list the supported launch years as 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, and 2019.",
    )

    bridge_pairs = [
        ("twenty twelve", "2012", "twenty eighteen", "2018"),
        ("twenty thirteen", "2013", "twenty nineteen", "2019"),
        ("twenty fifteen", "2015", "twenty twenty four", "2024"),
        ("twenty sixteen", "2016", "twenty twenty eight", "2028"),
    ]
    for first_spoken, first_digits, second_spoken, second_digits in bridge_pairs:
        add(
            examples,
            seen,
            "spoken_year_mixed",
            f"It feels like we have been doing this since {first_spoken}, but it is only {second_spoken}.",
            f"It feels like we have been doing this since {first_digits}, but it is only {second_digits}.",
        )

    for spoken, digits in QUANTITIES:
        add(
            examples,
            seen,
            "quantity_guard",
            f"QA found {spoken} visual issues, not a date.",
            f"QA found {digits} visual issues, not a date.",
        )
        add(
            examples,
            seen,
            "quantity_guard",
            f"Please order {spoken} labels and three backup cables.",
            f"Please order {digits} labels and 3 backup cables.",
        )

    for spoken, digits in TEEN_AGE_COMPOUNDS:
        add(
            examples,
            seen,
            "age_compound_guard",
            f"The repair shop restored a {spoken} year old frame without replacing the bridge.",
            f"The repair shop restored a {digits}-year-old frame without replacing the bridge.",
        )
        add(
            examples,
            seen,
            "age_compound_guard",
            f"We found a {spoken} year old case in storage and cleaned it carefully.",
            f"We found a {digits}-year-old case in storage and cleaned it carefully.",
        )
        add(
            examples,
            seen,
            "age_quantity_guard",
            f"The archive has {spoken} invoices, {spoken} labels, and a {spoken} year old receipt.",
            f"The archive has {digits} invoices, {digits} labels, and a {digits}-year-old receipt.",
        )

    age_guard_pairs = [
        (
            "And it's funny because all of those tools I had years ago came in handy to restore an eighteen year old pair of glasses.",
            "It is funny because all of those tools I had years ago came in handy to restore an 18-year-old pair of glasses.",
        ),
        (
            "The archive included an eight year old pair of glasses, an eighteen year old pair of glasses, and eighty year old paperwork.",
            "The archive included an 8-year-old pair of glasses, an 18-year-old pair of glasses, and 80-year-old paperwork.",
        ),
        (
            "The technician restored an eighteen year old pair of glasses, not an eight year old pair.",
            "The technician restored an 18-year-old pair of glasses, not an 8-year-old pair.",
        ),
        (
            "I found an eight year old case next to an eighteen year old pair of glasses.",
            "I found an 8-year-old case next to an 18-year-old pair of glasses.",
        ),
        (
            "The optician compared an eight year old receipt with an eighteen year old receipt.",
            "The optician compared an 8-year-old receipt with an 18-year-old receipt.",
        ),
        (
            "Please do not confuse eight years of wear with eighteen years of wear.",
            "Please do not confuse 8 years of wear with 18 years of wear.",
        ),
        (
            "The note mentioned eighteen years of use and an eighteen year old hinge.",
            "The note mentioned 18 years of use and an 18-year-old hinge.",
        ),
        (
            "Please keep the meaning clear: eighteen year old glasses are different from eight year old glasses.",
            "Please keep the meaning clear: 18-year-old glasses are different from 8-year-old glasses.",
        ),
    ]
    for user, assistant in age_guard_pairs:
        add(examples, seen, "age_compound_guard", user, assistant)

    guard_pairs = [
        (
            "The budget is five thousand twenty two dollars, and the backup estimate is six thousand one hundred.",
            "The budget is $5,022, and the backup estimate is $6,100.",
        ),
        (
            "For the invoice, the customer paid one thousand two hundred dollars in twenty twenty four.",
            "For the invoice, the customer paid $1,200 in 2024.",
        ),
        (
            "Sarah and me was reviewing twenty seven pieces of feedback at eleven thirty.",
            "Sarah and I were reviewing 27 pieces of feedback at 11:30.",
        ),
        (
            "I ain't worried about the build, but the screenshots still need a final pass.",
            "I'm not worried about the build, but the screenshots still need a final pass.",
        ),
        (
            "The customer asked whether the invoice should show one hundred eighty dollars or one thousand eight hundred dollars.",
            "The customer asked whether the invoice should show $180 or $1,800.",
        ),
        (
            "Please keep one hundred eighty dollars as one hundred eighty dollars, not one thousand eight hundred.",
            "Please keep $180 as $180, not $1,800.",
        ),
        (
            "The adjustment was one hundred eighty dollars, and the annual total was one thousand eight hundred dollars.",
            "The adjustment was $180, and the annual total was $1,800.",
        ),
        (
            "The archive includes twenty ten, twenty eleven, twenty twelve, twenty thirteen, twenty fourteen, twenty fifteen, twenty sixteen, twenty seventeen, twenty eighteen, and twenty nineteen.",
            "The archive includes 2010, 2011, 2012, 2013, 2014, 2015, 2016, 2017, 2018, and 2019.",
        ),
        (
            "Here are the follow-up tasks:\n\n1. Um review screenshots\n2. Like send the recap\n3. Submit notes",
            "Here are the follow-up tasks:\n\n1. Review screenshots\n2. Send the recap\n3. Submit notes",
        ),
        (
            "Um hey team, I looked at the April twenty second launch notes, and there are like three things we need to clean up. Sarah and me was reviewing the checklist at eleven thirty, and we found two minor issues. I ain't worried about the build, but the screenshots still need a final pass.\n\nOkay, so the customer paid one thousand two hundred dollars in twenty twenty four. They was asking whether the invoice, um, should show the discount as fifteen percent or as one hundred eighty dollars. I seen the same confusion last week, and we should make the update clear.\n\nFor follow up, please confirm the invoice, like send the April twenty second recap, and ask Jordan if the three screenshots are final. We should keep the tone professional but direct. I don't want the meaning to change.",
            "Hey team, I looked at the April 22nd launch notes, and there are 3 things we need to clean up. Sarah and I were reviewing the checklist at 11:30, and we found 2 minor issues. I'm not worried about the build, but the screenshots still need a final pass.\n\nThe customer paid $1,200 in 2024. They were asking whether the invoice should show the discount as 15% or as $180. I saw the same confusion last week, and we should make the update clear.\n\nFor follow-up, please confirm the invoice, send the April 22nd recap, and ask Jordan if the 3 screenshots are final. We should keep the tone professional but direct. I don't want the meaning to change.",
        ),
    ]
    for user, assistant in guard_pairs:
        add(examples, seen, "live_regression_guard", user, assistant)

    random.Random(23).shuffle(examples)
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
            "I can't believe so much time has passed. I haven't seen you since 2012.",
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
            "live_regression_guard",
            "I ain't changing the invoice from one hundred eighty dollars.",
            "I'm not changing the invoice from $180.",
        ),
        Example(
            "age_compound_guard",
            "This repair needs a sixteen year old hinge and an eighteen year old frame.",
            "This repair needs a 16-year-old hinge and an 18-year-old frame.",
        ),
    ]
    test = [
        Example(
            "spoken_year_mixed",
            "It feels like we have been doing this since twenty twelve, but it is only twenty eighteen.",
            "It feels like we have been doing this since 2012, but it is only 2018.",
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
            "live_regression_guard",
            "Sarah and me was checking the list at three thirty.",
            "Sarah and I were checking the list at 3:30.",
        ),
        Example(
            "age_compound_guard",
            "The optician repaired an eighteen year old pair of glasses with a nineteen year old tool.",
            "The optician repaired an 18-year-old pair of glasses with a 19-year-old tool.",
        ),
    ]

    valid_inputs = {example.user for example in valid}
    test_inputs = {example.user for example in test}
    train = [example for example in examples if example.user not in valid_inputs and example.user not in test_inputs]

    write_split(DATA_DIR / "train.jsonl", train)
    write_split(DATA_DIR / "valid.jsonl", valid)
    write_split(DATA_DIR / "test.jsonl", test)

    manifest = {
        "version": "polished-alpha-024",
        "purpose": "continuation from alpha-023 for teen-number age compound precision and quantity guards",
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
