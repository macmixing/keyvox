#!/usr/bin/env python3
import json
import sys
from collections import Counter
from pathlib import Path


EXPECTED_FILES = ("train.jsonl", "valid.jsonl", "test.jsonl")
EXPECTED_ROLES = ["system", "user", "assistant"]
UNCHANGED_OK = {
    "no_op",
    "grammar_preservation",
    "profanity_slang_preservation",
    "like_preservation",
    "numeric_formatting",
    "structure_preservation",
    "casual_voice_guard",
}


def fail(message: str) -> None:
    raise ValueError(message)


def load_jsonl(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                yield line_number, json.loads(stripped)
            except json.JSONDecodeError as error:
                fail(f"{path}:{line_number} invalid JSON: {error}")


def validate_record(path: Path, line_number: int, record: dict) -> tuple[str, str, str]:
    messages = record.get("messages")
    if not isinstance(messages, list) or len(messages) != 3:
        fail(f"{path}:{line_number} expected exactly 3 messages")

    roles = [message.get("role") for message in messages]
    if roles != EXPECTED_ROLES:
        fail(f"{path}:{line_number} expected roles {EXPECTED_ROLES}")

    contents = []
    for message in messages:
        content = message.get("content")
        if not isinstance(content, str) or not content.strip():
            fail(f"{path}:{line_number} message content must be non-empty")
        contents.append(content)

    category = record.get("category", "uncategorized")
    if not isinstance(category, str) or not category:
        fail(f"{path}:{line_number} category must be a non-empty string")

    return category, contents[1], contents[2]


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: validate_dataset.py <data-directory>", file=sys.stderr)
        return 2

    data_dir = Path(sys.argv[1])
    seen_inputs: dict[str, Path] = {}
    total = 0

    for filename in EXPECTED_FILES:
        path = data_dir / filename
        if not path.exists():
            print(f"missing {path}", file=sys.stderr)
            return 1

        count = 0
        categories = Counter()
        for line_number, record in load_jsonl(path):
            category, user_text, assistant_text = validate_record(path, line_number, record)
            if user_text in seen_inputs:
                fail(f"{path}:{line_number} duplicates input from {seen_inputs[user_text]}")
            if user_text == assistant_text and category not in UNCHANGED_OK:
                fail(f"{path}:{line_number} unchanged output appears in category {category}")
            seen_inputs[user_text] = path
            categories[category] += 1
            count += 1

        if count == 0:
            fail(f"{path} has no examples")

        total += count
        print(f"{filename}: {count} examples")
        for category, category_count in sorted(categories.items()):
            print(f"  {category}: {category_count}")

    print(f"total: {total} examples")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
