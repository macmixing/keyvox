#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-1-base"
REPORT_DIR = ROOT / "reports"
SYSTEM_PROMPT = (
    MODEL_TRAINING_ROOT / "prompts" / "casual" / "casual_training_system.txt"
).read_text(encoding="utf-8").strip()
RANDOM_SEED = 4101
TRAIN_COUNT = 2000
VALID_COUNT = 200
TEST_COUNT = 200


@dataclass(frozen=True)
class Example:
    category: str
    user: str
    assistant: str


def clean_filler(text: str) -> str:
    replacements = [
        ("Um, ", ""),
        ("Um ", ""),
        ("um, ", ""),
        ("um ", ""),
        ("Uh, ", ""),
        ("Uh ", ""),
        ("uh, ", ""),
        ("uh ", ""),
        ("Hm, ", ""),
        ("Hm ", ""),
        ("hm, ", ""),
        ("hm ", ""),
        ("Ah, ", ""),
        ("Ah ", ""),
        ("ah, ", ""),
        ("ah ", ""),
        ("Er, ", ""),
        ("Er ", ""),
        ("er, ", ""),
        ("er ", ""),
        (", um,", ","),
        (", uh,", ","),
        (", hm,", ","),
        (", ah,", ","),
        (", er,", ","),
        (" um,", ","),
        (" uh,", ","),
        (" hm,", ","),
        (" ah,", ","),
        (" er,", ","),
        ("  ", " "),
    ]
    output = text
    for old, new in replacements:
        output = output.replace(old, new)
    return output.strip()


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


subjects = [
    "the button",
    "the build",
    "the keyboard",
    "the adapter",
    "the release",
    "the status label",
    "the invoice",
    "the signup flow",
    "the settings screen",
    "the export",
]

actions = [
    "works after I restart the app",
    "still feels weird on my phone",
    "needs one more pass tomorrow",
    "shows the right state now",
    "keeps the original text around",
    "made the whole thing feel faster",
    "doesn't need a full rewrite",
    "should stay exactly how I said it",
    "is ready for another test",
    "probably needs a quick check",
]

fillers = ["um", "uh", "hm", "ah", "er"]
openers = ["Hey", "Okay", "So", "Yeah", "Look", "Honestly"]
people = ["Sarah", "Jordan", "Maya", "Alex", "Taylor", "Jamie"]
slang_lines = [
    "this thing is kinda wild",
    "that button is super janky",
    "the flow feels pretty dope now",
    "the old version was lowkey annoying",
    "this update is sick when it works",
    "that screen is still a mess",
]
profanity_lines = [
    "why the fuck is this still happening",
    "this shit finally works on my phone",
    "that bug was fucking annoying yesterday",
    "I don't want this damn thing changing my words",
    "the button is still acting weird as hell",
]
bad_grammar_lines = [
    "What you be doing after work?",
    "Sarah and me was testing the keyboard.",
    "They was looking at the invoice yesterday.",
    "I seen the same bug on my phone.",
    "Me and Jordan was talking about the launch.",
    "You be making this harder than it needs to be.",
    "I ain't doing that today.",
    "That ain't nothing we need to fix right now.",
    "She ain't seen the update yet.",
    "We ain't going back to the old version.",
]
numeric_pairs = [
    ("I paid five hundred dollars for the repair.", "I paid $500 for the repair."),
    ("The invoice is one thousand two hundred dollars.", "The invoice is $1,200."),
    ("Let's meet on April twenty second.", "Let's meet on April 22nd."),
    ("Move the call to 11:30.", "Move the call to 11:30."),
    ("The total is one hundred eighty dollars.", "The total is $180."),
    ("The customer renewed in twenty twenty four.", "The customer renewed in 2024."),
    ("Revenue was up twelve percent.", "Revenue was up 12%."),
    ("The quote has three seats and twenty five add-ons.", "The quote has 3 seats and 25 add-ons."),
    ("The follow up is on June fifth at 3:30.", "The follow up is on June 5th at 3:30."),
    ("The backup estimate is six thousand one hundred dollars.", "The backup estimate is $6,100."),
]
followups = [
    "Please keep it casual.",
    "I want the same wording back.",
    "This should not sound polished.",
    "Do not make it professional.",
    "That is exactly how I said it.",
    "The voice should stay mine.",
    "This is just a cleanup pass.",
    "Keep the meaning from start to finish.",
]
list_headers = [
    "I need groceries",
    "Here are the launch tasks",
    "Things that ain't done",
    "Bug notes",
    "For tomorrow",
    "Quick checklist",
    "Stuff to send Jordan",
    "Release notes",
]
list_items = [
    ("apples", "bananas", "grapes"),
    ("apples", "bananas", "fucking grapes"),
    ("screenshots", "final copy", "release notes"),
    ("button gets stuck", "label stays yellow", "text is editable"),
    ("call Alex at 11:30", "send the $180 invoice", "check the 2024 report"),
    ("write the draft", "review the build", "send the update"),
    ("the damn button", "the weird label", "the old text"),
]


def make_no_op_examples() -> list[Example]:
    examples = []
    for subject in subjects:
        for action in actions:
            text = f"I think {subject} {action}."
            examples.append(record("no_op", text, text))
            text = f"Like honestly, I think {subject} {action}."
            examples.append(record("like_preservation", text, text))
            text = f"{subject.capitalize()} {action}, and I ain't changing that."
            examples.append(record("grammar_preservation", text, text))
    for line in slang_lines + profanity_lines + bad_grammar_lines:
        examples.append(record("no_op", line, line))
    return examples


def make_filler_examples() -> list[Example]:
    examples = []
    for opener in openers:
        for filler in fillers:
            for subject in subjects:
                for action in actions:
                    user = f"{opener}, {filler}, I think {subject} {action}."
                    assistant = f"{opener}, I think {subject} {action}."
                    examples.append(record("filler_cleanup", user, assistant))

    for filler in fillers:
        for subject in subjects:
            for action in actions:
                user = f"I tested {subject}, {filler}, and it {action}."
                assistant = f"I tested {subject}, and it {action}."
                examples.append(record("filler_cleanup", user, assistant))
    return examples


def make_like_examples() -> list[Example]:
    examples = []
    for subject in subjects:
        for action in actions:
            user = f"Um I like really think {subject} {action}."
            assistant = f"I like really think {subject} {action}."
            examples.append(record("like_preservation", user, assistant))
            text = f"I was like maybe {subject} {action}."
            examples.append(record("like_preservation", text, text))
    for line in [
        "Like I said, the keyboard should keep my words.",
        "I feel like this is finally close.",
        "It's like the status label was the missing piece.",
        "This is like exactly what I wanted.",
    ]:
        examples.append(record("like_preservation", line, line))
    return examples


def make_grammar_preservation_examples() -> list[Example]:
    examples = []
    for line in bad_grammar_lines:
        examples.append(record("grammar_preservation", line, line))
        user = f"Um {line}"
        examples.append(record("grammar_preservation", user, clean_filler(user)))
        for followup in followups:
            user = f"{line} Uh {followup}"
            assistant = f"{line} {followup}"
            examples.append(record("grammar_preservation", user, assistant))
        for subject in subjects:
            user = f"Um {line} I think {subject} should stay casual."
            assistant = f"{line} I think {subject} should stay casual."
            examples.append(record("grammar_preservation", user, assistant))
    return examples


def make_profanity_slang_examples() -> list[Example]:
    examples = []
    for line in slang_lines + profanity_lines:
        examples.append(record("profanity_slang_preservation", line, line))
        user = f"Um {line}."
        assistant = f"{line}."
        examples.append(record("profanity_slang_preservation", user, assistant))
        for followup in followups:
            user = f"{line}, uh, and {followup[0].lower()}{followup[1:]}"
            assistant = f"{line}, and {followup[0].lower()}{followup[1:]}"
            examples.append(record("profanity_slang_preservation", user, assistant))
        for subject in subjects:
            user = f"Um {line}, and {subject} should keep that vibe."
            assistant = f"{line}, and {subject} should keep that vibe."
            examples.append(record("profanity_slang_preservation", user, assistant))
            user = f"{line}, uh, because {subject} still matters."
            assistant = f"{line}, because {subject} still matters."
            examples.append(record("profanity_slang_preservation", user, assistant))
    return examples


def make_numeric_examples() -> list[Example]:
    examples = []
    for user, assistant in numeric_pairs:
        examples.append(record("numeric_formatting", user, assistant))
        examples.append(record("numeric_formatting", f"Um {user}", assistant))
        examples.append(record("numeric_formatting", f"{user} Uh please keep that.", f"{assistant} Please keep that."))
        for opener in openers:
            examples.append(record("numeric_formatting", f"{opener}, um, {user}", f"{opener}, {assistant}"))
        for followup in followups:
            examples.append(record("numeric_formatting", f"{user} Uh {followup}", f"{assistant} {followup}"))
        for subject in subjects:
            examples.append(record("numeric_formatting", f"For {subject}, um, {user}", f"For {subject}, {assistant}"))
        examples.append(record("numeric_formatting", f"Like {user}", f"Like {assistant}"))
        examples.append(record("numeric_formatting", f"Honestly, {user}", f"Honestly, {assistant}"))
        examples.append(record("numeric_formatting", f"Quick note: {user}", f"Quick note: {assistant}"))
    combined_pairs = [
        (
            "Move the call to 11:30 and send the one hundred eighty dollar invoice.",
            "Move the call to 11:30 and send the $180 invoice.",
        ),
        (
            "The meeting is at 3:30, and the invoice is five hundred dollars.",
            "The meeting is at 3:30, and the invoice is $500.",
        ),
        (
            "The follow up is April twenty second at 11:30, and the total is one thousand two hundred dollars.",
            "The follow up is April 22nd at 11:30, and the total is $1,200.",
        ),
    ]
    for user, assistant in combined_pairs:
        examples.append(record("numeric_formatting", user, assistant))
        examples.append(record("numeric_formatting", f"Um {user}", assistant))
        examples.append(record("numeric_formatting", f"Like {user}", f"Like {assistant}"))
    return examples


def make_list_examples() -> list[Example]:
    examples = []
    for header in list_headers:
        for first, second, third in list_items:
            for filler_a, filler_b in [("Um", "Uh"), ("Uh", "Um"), ("Hm", "Ah")]:
                user = f"{header}:\n\n1. {filler_a} {first}\n2. Like {second}\n3. {filler_b} {third}"
                assistant = f"{header}:\n\n1. {first[0].upper()}{first[1:]}\n2. Like {second}\n3. {third[0].upper()}{third[1:]}"
                examples.append(record("list_preservation", user, assistant))
                user = f"{header}:\n\n- {filler_b} {first}\n- Like {second}\n- {filler_a} {third}"
                assistant = f"{header}:\n\n- {first[0].upper()}{first[1:]}\n- Like {second}\n- {third[0].upper()}{third[1:]}"
                examples.append(record("list_preservation", user, assistant))
    return examples


def make_paragraph_examples() -> list[Example]:
    examples = []
    for subject in subjects:
        for action in actions:
            user = f"Um I tested {subject} for a while, and like it {action}.\n\nUh the second paragraph should stay separate because it has a different thought."
            assistant = f"I tested {subject} for a while, and like it {action}.\n\nThe second paragraph should stay separate because it has a different thought."
            examples.append(record("structure_preservation", user, assistant))
            user = f"Okay, {subject} {action}.\n\nHm I ain't asking for a rewrite, just cleanup.\n\nUh the last paragraph should still be here."
            assistant = f"Okay, {subject} {action}.\n\nI ain't asking for a rewrite, just cleanup.\n\nThe last paragraph should still be here."
            examples.append(record("structure_preservation", user, assistant))
            user = f"Like the first paragraph says {subject} {action}.\n\nAh the second paragraph has $180 and April 22nd.\n\nEr the third paragraph says Sarah and me was testing it."
            assistant = f"Like the first paragraph says {subject} {action}.\n\nThe second paragraph has $180 and April 22nd.\n\nThe third paragraph says Sarah and me was testing it."
            examples.append(record("structure_preservation", user, assistant))
    for line in bad_grammar_lines:
        user = f"The first paragraph ain't polished and it should stay that way.\n\nUh {line}"
        assistant = f"The first paragraph ain't polished and it should stay that way.\n\n{line}"
        examples.append(record("structure_preservation", user, assistant))
    return examples


def make_long_examples() -> list[Example]:
    examples = []
    for person in people:
        for subject in subjects:
            for opener in ["Um", "Uh"]:
                user = (
                    f"{opener} {person} and me was testing {subject} for a little bit, and like it mostly kept the words in place. "
                    "I ain't asking it to sound professional, I just want the filler gone. "
                "The invoice is one hundred eighty dollars, and the follow up is April twenty second at 11:30."
                )
                assistant = (
                    f"{person} and me was testing {subject} for a little bit, and like it mostly kept the words in place. "
                    "I ain't asking it to sound professional, I just want the filler gone. "
                "The invoice is $180, and the follow up is April 22nd at 11:30."
                )
                examples.append(record("long_mixed", user, assistant))
    return examples


def make_gauntlet_structure_examples() -> list[Example]:
    examples = []
    for person in people:
        for subject in subjects:
            user = (
                f"Um okay, like I tested {subject} for 20 minutes, and I ain't saying it's perfect. "
                f"{person} and me was trying a few weird cases, and what you be doing matters less than whether the words stay put.\n\n"
                "Uh the list still needs to work:\n\n"
                "1. Like apples\n"
                "2. Um bananas\n"
                "3. Fucking grapes\n\n"
                "Hm the final note is that the invoice shows $180, the date is April 22nd, and the follow up is at 11:30."
            )
            assistant = (
                f"okay, like I tested {subject} for 20 minutes, and I ain't saying it's perfect. "
                f"{person} and me was trying a few weird cases, and what you be doing matters less than whether the words stay put.\n\n"
                "The list still needs to work:\n\n"
                "1. Like apples\n"
                "2. Bananas\n"
                "3. Fucking grapes\n\n"
                "The final note is that the invoice shows $180, the date is April 22nd, and the follow up is at 11:30."
            )
            examples.append(record("gauntlet_structure", user, assistant))

            user = (
                "Uh first paragraph is just me talking like normal, and this shit should not get polished. "
                "I ain't trying to make it sound fancy.\n\n"
                f"Um second paragraph has {person} and me was checking {subject}, and they was looking at the old text. "
                "Like the whole point is to keep the voice.\n\n"
                "Hm third paragraph has a list:\n\n"
                "- Um full access copy\n"
                "- Like yellow label state\n"
                "- Uh undo behavior\n\n"
                "Ah fourth paragraph says the total is five hundred dollars, the renewal is twenty twenty four, and the meeting is at 3:30."
            )
            assistant = (
                "first paragraph is just me talking like normal, and this shit should not get polished. "
                "I ain't trying to make it sound fancy.\n\n"
                f"second paragraph has {person} and me was checking {subject}, and they was looking at the old text. "
                "Like the whole point is to keep the voice.\n\n"
                "third paragraph has a list:\n\n"
                "- Full access copy\n"
                "- Like yellow label state\n"
                "- Undo behavior\n\n"
                "fourth paragraph says the total is $500, the renewal is 2024, and the meeting is at 3:30."
            )
            examples.append(record("gauntlet_structure", user, assistant))
    return examples


def build_examples() -> list[Example]:
    examples = []
    examples.extend(make_no_op_examples())
    examples.extend(make_filler_examples())
    examples.extend(make_like_examples())
    examples.extend(make_grammar_preservation_examples())
    examples.extend(make_profanity_slang_examples())
    examples.extend(make_numeric_examples())
    examples.extend(make_list_examples())
    examples.extend(make_paragraph_examples())
    examples.extend(make_long_examples())
    examples.extend(make_gauntlet_structure_examples())

    expanded = list(examples)
    for subject in subjects:
        for filler in fillers:
            for action in actions:
                user = f"I think {subject}, {filler}, like {action}."
                assistant = f"I think {subject}, like {action}."
                expanded.append(record("keep_like_remove_filler", user, assistant))

    for line in bad_grammar_lines:
        for filler in fillers[:3]:
            user = f"{filler.capitalize()}, {line} Like that's just what happened."
            assistant = f"{line} Like that's just what happened."
            expanded.append(record("grammar_preservation", user, assistant))

    for user, assistant in numeric_pairs:
        expanded.append(record("numeric_formatting", f"Like {user}", f"Like {assistant}"))

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

    unique: dict[str, Example] = {}
    for example in build_examples():
        unique.setdefault(example.user, example)

    examples = list(unique.values())
    by_category: dict[str, list[Example]] = {}
    for example in examples:
        by_category.setdefault(example.category, []).append(example)
    for category_examples in by_category.values():
        random.shuffle(category_examples)

    targets = {
        "filler_cleanup": 520,
        "keep_like_remove_filler": 180,
        "like_preservation": 260,
        "grammar_preservation": 320,
        "profanity_slang_preservation": 240,
        "numeric_formatting": 300,
        "list_preservation": 230,
        "structure_preservation": 250,
        "long_mixed": 80,
        "gauntlet_structure": 120,
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
        "version": "casual-alpha-1",
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
