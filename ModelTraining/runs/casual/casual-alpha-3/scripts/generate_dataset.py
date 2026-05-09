#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-3-continuation-time-money-guards"
REPORT_DIR = ROOT / "reports"
SYSTEM_PROMPT = (
    MODEL_TRAINING_ROOT / "prompts" / "casual" / "casual_training_system.txt"
).read_text(encoding="utf-8").strip()
RANDOM_SEED = 4203
TRAIN_COUNT = 720
VALID_COUNT = 90
TEST_COUNT = 90


@dataclass(frozen=True)
class Example:
    category: str
    user: str
    assistant: str


def record(category: str, user: str, assistant: str) -> Example:
    return Example(category=category, user=user, assistant=assistant)


def render(example: Example) -> str:
    return json.dumps(
        {
            "category": example.category,
            "messages": [
                {"role": "system", "content": SYSTEM_PROMPT},
                {"role": "user", "content": example.user},
                {"role": "assistant", "content": example.assistant},
            ],
        },
        ensure_ascii=False,
    )


hours = [
    ("one", "1"),
    ("two", "2"),
    ("three", "3"),
    ("four", "4"),
    ("five", "5"),
    ("six", "6"),
    ("seven", "7"),
    ("eight", "8"),
    ("nine", "9"),
    ("ten", "10"),
    ("eleven", "11"),
    ("twelve", "12"),
]

minutes = [
    ("oh one", "01"),
    ("oh five", "05"),
    ("ten", "10"),
    ("fifteen", "15"),
    ("twenty", "20"),
    ("twenty five", "25"),
    ("thirty", "30"),
    ("thirty five", "35"),
    ("forty", "40"),
    ("forty five", "45"),
    ("fifty", "50"),
    ("fifty five", "55"),
]

time_templates = [
    ("Hey, can you meet me for lunch tomorrow at {spoken}?", "Hey, can you meet me for lunch tomorrow at {clock}?"),
    ("Can you meet me at {spoken} tomorrow?", "Can you meet me at {clock} tomorrow?"),
    ("Let's check in at {spoken} if that works.", "Let's check in at {clock} if that works."),
    ("Move the follow up to {spoken} and keep it casual.", "Move the follow up to {clock} and keep it casual."),
    ("Remind me to text Jordan at {spoken}.", "Remind me to text Jordan at {clock}."),
    ("The customer call is at {spoken} tomorrow.", "The customer call is at {clock} tomorrow."),
    ("Put the review at {spoken} and send the note after.", "Put the review at {clock} and send the note after."),
    ("I can probably make it by {spoken}, but don't polish this.", "I can probably make it by {clock}, but don't polish this."),
    ("Um can you call me at {spoken}?", "Can you call me at {clock}?"),
    ("Uh remind me at {spoken} to check the build.", "Remind me at {clock} to check the build."),
    ("Like can we talk at {spoken} about the keyboard?", "Like can we talk at {clock} about the keyboard?"),
    ("Sarah and me was going to meet at {spoken}.", "Sarah and me was going to meet at {clock}."),
    ("I ain't showing up before {spoken}.", "I ain't showing up before {clock}."),
    ("This shit needs to be done by {spoken}.", "This shit needs to be done by {clock}."),
]

guard_examples = [
    record("keep_like_remove_filler", "Hey, um, like are you coming over later?", "Hey, like are you coming over later?"),
    record("keep_like_remove_filler", "Um I like really think the keyboard is close.", "I like really think the keyboard is close."),
    record("grammar_preservation", "What you be doing after work?", "What you be doing after work?"),
    record("grammar_preservation", "Sarah and me was testing the keyboard.", "Sarah and me was testing the keyboard."),
    record("grammar_preservation", "I ain't doing that today.", "I ain't doing that today."),
    record("profanity_slang_preservation", "Why the fuck is this button still weird?", "Why the fuck is this button still weird?"),
    record("profanity_slang_preservation", "Um this shit finally works on my phone.", "This shit finally works on my phone."),
    record("list_preservation", "I need groceries:\n\n1. Um apples\n2. Like bananas\n3. Uh grapes", "I need groceries:\n\n1. Apples\n2. Like bananas\n3. Grapes"),
    record("structure_preservation", "Um I tested this for a little bit, and like it mostly works.\n\nUh the second paragraph should stay separate.", "I tested this for a little bit, and like it mostly works.\n\nThe second paragraph should stay separate."),
    record("numeric_formatting", "Move the call to 11:30 and send the one hundred eighty dollar invoice.", "Move the call to 11:30 and send the $180 invoice."),
    record("numeric_formatting", "The renewal is twenty twenty four and the total is five hundred dollars.", "The renewal is 2024 and the total is $500."),
    record("numeric_formatting", "The total is five hundred dollars.", "The total is $500."),
    record("numeric_formatting", "The estimate was five hundred dollars even.", "The estimate was $500 even."),
    record("numeric_formatting", "The total is five thousand one hundred dollars.", "The total is $5,100."),
]

guard_subjects = [
    "the keyboard",
    "the adapter",
    "the status label",
    "the invoice",
    "the build",
    "the settings screen",
    "the export",
    "the release",
]

guard_actions = [
    "still feels weird",
    "looks pretty close",
    "needs another pass",
    "should stay casual",
    "keeps the voice",
    "does not need polishing",
]

bad_grammar_lines = [
    "What you be doing after work?",
    "Sarah and me was testing the keyboard.",
    "They was looking at the invoice yesterday.",
    "I seen the same bug on my phone.",
    "Me and Jordan was talking about the launch.",
    "I ain't doing that today.",
    "That ain't nothing we need to fix right now.",
]

profanity_lines = [
    "Why the fuck is this button still weird?",
    "This shit finally works on my phone.",
    "That bug was fucking annoying yesterday.",
    "I don't want this damn thing changing my words.",
]


def make_spoken_time_examples() -> list[Example]:
    examples: list[Example] = []
    for hour_word, hour_number in hours:
        for minute_word, minute_number in minutes:
            spoken = f"{hour_word} {minute_word}"
            clock = f"{hour_number}:{minute_number}"
            for user_template, assistant_template in time_templates:
                examples.append(
                    record(
                        "spoken_time_formatting",
                        user_template.format(spoken=spoken, clock=clock),
                        assistant_template.format(spoken=spoken, clock=clock),
                    )
                )

    fixed_failures = [
        ("Hey, can you meet me for lunch tomorrow at three fifteen?", "Hey, can you meet me for lunch tomorrow at 3:15?"),
        ("Hey, can you meet me for lunch tomorrow at four forty five?", "Hey, can you meet me for lunch tomorrow at 4:45?"),
        ("Can you meet me tomorrow at three fifteen?", "Can you meet me tomorrow at 3:15?"),
        ("Can you meet me tomorrow at four forty five?", "Can you meet me tomorrow at 4:45?"),
    ]
    examples.extend(record("spoken_time_formatting", user, assistant) for user, assistant in fixed_failures)
    return examples


def make_guard_examples() -> list[Example]:
    examples = list(guard_examples)

    for subject in guard_subjects:
        for action in guard_actions:
            examples.append(
                record(
                    "keep_like_remove_filler",
                    f"Um I like really think {subject} {action}.",
                    f"I like really think {subject} {action}.",
                )
            )
            examples.append(
                record(
                    "keep_like_remove_filler",
                    f"I think {subject}, uh, like {action}.",
                    f"I think {subject}, like {action}.",
                )
            )
            examples.append(
                record(
                    "structure_preservation",
                    f"Um I tested {subject}, and like it {action}.\n\nUh the second paragraph should stay separate.",
                    f"I tested {subject}, and like it {action}.\n\nThe second paragraph should stay separate.",
                )
            )

    for line in bad_grammar_lines:
        examples.append(record("grammar_preservation", line, line))
        examples.append(record("grammar_preservation", f"Um {line}", line))
        for subject in guard_subjects:
            examples.append(
                record(
                    "grammar_preservation",
                    f"Um {line} I think {subject} should stay casual.",
                    f"{line} I think {subject} should stay casual.",
                )
            )

    for line in profanity_lines:
        examples.append(record("profanity_slang_preservation", line, line))
        examples.append(record("profanity_slang_preservation", f"Um {line}", line))
        for subject in guard_subjects:
            examples.append(
                record(
                    "profanity_slang_preservation",
                    f"{line} Uh {subject} still matters.",
                    f"{line} {subject} still matters.",
                )
            )

    list_headers = [
        "I need groceries",
        "Quick checklist",
        "Bug notes",
        "For tomorrow",
        "Release notes",
    ]
    list_items = [
        ("apples", "bananas", "grapes"),
        ("screenshots", "final copy", "release notes"),
        ("button gets stuck", "label stays yellow", "text is editable"),
        ("the damn button", "the weird label", "the old text"),
    ]
    for header in list_headers:
        for first, second, third in list_items:
            examples.append(
                record(
                    "list_preservation",
                    f"{header}:\n\n1. Um {first}\n2. Like {second}\n3. Uh {third}",
                    f"{header}:\n\n1. {first[0].upper()}{first[1:]}\n2. Like {second}\n3. {third[0].upper()}{third[1:]}",
                )
            )

    numeric_pairs = [
        ("The renewal is twenty twenty four.", "The renewal is 2024."),
        ("The total is five hundred dollars.", "The total is $500."),
        ("The invoice is five hundred dollars.", "The invoice is $500."),
        ("The estimate is five hundred dollars.", "The estimate is $500."),
        ("The budget is five hundred dollars.", "The budget is $500."),
        ("The deposit is five hundred dollars.", "The deposit is $500."),
        ("The charge was five hundred dollars.", "The charge was $500."),
        ("The total is five thousand one hundred dollars.", "The total is $5,100."),
        ("The invoice is five thousand one hundred dollars.", "The invoice is $5,100."),
        ("The quote has three seats and twenty five add-ons.", "The quote has 3 seats and 25 add-ons."),
        ("Revenue was up twelve percent.", "Revenue was up 12%."),
        ("The invoice is one thousand two hundred dollars.", "The invoice is $1,200."),
    ]
    for user, assistant in numeric_pairs:
        examples.append(record("numeric_formatting", user, assistant))
        examples.append(record("numeric_formatting", f"Um {user}", assistant))
        for subject in guard_subjects:
            examples.append(record("numeric_formatting", f"For {subject}, {user}", f"For {subject}, {assistant}"))

    return examples


def build_examples() -> list[Example]:
    expanded: list[Example] = []
    expanded.extend(make_spoken_time_examples())
    expanded.extend(make_guard_examples())

    unique: dict[str, Example] = {}
    for example in expanded:
        unique.setdefault(example.user, example)
    return list(unique.values())


def write_split(path: Path, examples: list[Example]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for example in examples:
            handle.write(render(example))
            handle.write("\n")


def main() -> int:
    random.seed(RANDOM_SEED)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    by_category: dict[str, list[Example]] = {}
    for example in build_examples():
        by_category.setdefault(example.category, []).append(example)
    for category_examples in by_category.values():
        random.shuffle(category_examples)

    targets = {
        "spoken_time_formatting": 565,
        "keep_like_remove_filler": 50,
        "grammar_preservation": 70,
        "profanity_slang_preservation": 40,
        "list_preservation": 20,
        "structure_preservation": 45,
        "numeric_formatting": 110,
    }

    selected: list[Example] = []
    for category, count in targets.items():
        category_examples = by_category.get(category, [])
        if len(category_examples) < count:
            raise RuntimeError(f"not enough {category} examples: {len(category_examples)} < {count}")
        selected.extend(category_examples[:count])

    random.shuffle(selected)
    train = selected[:TRAIN_COUNT]
    valid = selected[TRAIN_COUNT:TRAIN_COUNT + VALID_COUNT]
    test = selected[TRAIN_COUNT + VALID_COUNT:TRAIN_COUNT + VALID_COUNT + TEST_COUNT]

    write_split(DATA_DIR / "train.jsonl", train)
    write_split(DATA_DIR / "valid.jsonl", valid)
    write_split(DATA_DIR / "test.jsonl", test)

    manifest = {
        "version": "casual-alpha-3",
        "seed": RANDOM_SEED,
        "counts": {
            "train": len(train),
            "valid": len(valid),
            "test": len(test),
            "total": len(train) + len(valid) + len(test),
        },
        "categories": dict(Counter(example.category for example in train + valid + test)),
    }
    (REPORT_DIR / "dataset_manifest.json").write_text(
        json.dumps(manifest, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps(manifest, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
