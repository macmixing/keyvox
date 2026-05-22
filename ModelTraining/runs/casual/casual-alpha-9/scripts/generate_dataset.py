#!/usr/bin/env python3
import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-9-continuation-rating-unlearn"
REPORT_DIR = ROOT / "reports"

SOURCE_DATASETS = [
    MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-5-continuation-money-boundaries",
    MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-6-continuation-money-negation-boundaries",
    MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-7-continuation-money-time-coverage",
    MODEL_TRAINING_ROOT / "datasets" / "casual" / "casual-alpha-8-continuation-address-time-guards",
]


def load_records(path: Path):
    with path.open("r", encoding="utf-8") as handle:
        for line in handle:
            stripped = line.strip()
            if stripped:
                yield json.loads(stripped)


def should_skip(record: dict) -> bool:
    messages = record.get("messages", [])
    if len(messages) < 3:
        return False

    assistant_text = messages[2].get("content", "")
    legacy_rating_marker = "5" + "-" + "star"
    return legacy_rating_marker in assistant_text


def write_split(filename: str) -> int:
    seen_inputs: set[str] = set()
    records: list[dict] = []

    for source in SOURCE_DATASETS:
        for source_record in load_records(source / filename):
            if should_skip(source_record):
                continue

            messages = source_record.get("messages", [])
            if len(messages) < 2:
                continue

            user_text = messages[1].get("content", "")
            if user_text in seen_inputs:
                continue

            seen_inputs.add(user_text)
            records.append(source_record)

    output_path = DATA_DIR / filename
    with output_path.open("w", encoding="utf-8") as handle:
        for record in records:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")

    return len(records)


def main() -> int:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    counts = {
        "train": write_split("train.jsonl"),
        "valid": write_split("valid.jsonl"),
        "test": write_split("test.jsonl"),
    }

    category_counts = Counter()
    for filename in ("train.jsonl", "valid.jsonl", "test.jsonl"):
        for record in load_records(DATA_DIR / filename):
            category_counts[record.get("category", "uncategorized")] += 1

    manifest = {
        "version": "casual-alpha-9",
        "purpose": "replay casual continuations with prior rating-formatting examples removed",
        "source_datasets": [str(path.relative_to(MODEL_TRAINING_ROOT)) for path in SOURCE_DATASETS],
        "train_count": counts["train"],
        "valid_count": counts["valid"],
        "test_count": counts["test"],
        "categories": category_counts,
    }
    with (REPORT_DIR / "dataset_manifest.json").open("w", encoding="utf-8") as handle:
        json.dump(manifest, handle, indent=2, sort_keys=True)
        handle.write("\n")

    print(
        f"wrote {counts['train']} train, {counts['valid']} valid, "
        f"{counts['test']} test examples to {DATA_DIR}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
