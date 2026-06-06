#!/usr/bin/env python3
import json
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
BAD_RATINGS_PATH = MODEL_TRAINING_ROOT.parent / "bad-ratings.json"
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "polished" / "alpha-027-continuation-meaning-preservation-ratings"
REPORT_DIR = ROOT / "reports"
PROMPT = (MODEL_TRAINING_ROOT / "prompts" / "polished" / "polished_runtime_short.txt").read_text(encoding="utf-8").strip()


@dataclass(frozen=True)
class Example:
    category: str
    user: str
    assistant: str
    split: str = "train"


def add(examples: list[Example], seen: set[str], example: Example) -> None:
    if example.user in seen:
        raise ValueError(f"duplicate user example: {example.user}")
    seen.add(example.user)
    examples.append(example)


def record(category: str, user: str, assistant: str) -> dict:
    return {
        "category": category,
        "messages": [
            {"role": "system", "content": PROMPT},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ],
    }


def load_bad_rating_summary() -> list[dict]:
    if not BAD_RATINGS_PATH.exists():
        manifest_path = REPORT_DIR / "dataset_manifest.json"
        if manifest_path.exists():
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            return manifest.get("bad_rating_records", [])
        return []

    payload = json.loads(BAD_RATINGS_PATH.read_text(encoding="utf-8"))
    return [
        {
            "capture_id": item.get("capture_id"),
            "source_text": item.get("source_text"),
            "visible_text": item.get("visible_text"),
            "style_identifier": item.get("style_identifier"),
        }
        for item in payload.get("records", [])
    ]


def build_examples() -> list[Example]:
    examples: list[Example] = []
    seen: set[str] = set()

    def train(category: str, user: str, assistant: str) -> None:
        add(examples, seen, Example(category, user, assistant, "train"))

    def valid(category: str, user: str, assistant: str) -> None:
        add(examples, seen, Example(category, user, assistant, "valid"))

    def test(category: str, user: str, assistant: str) -> None:
        add(examples, seen, Example(category, user, assistant, "test"))

    # Exact bad-rating seeds.
    train("negation_preservation", "The way I see it is there's no way it can't get eternally.", "The way I see it is, there's no way it can't get eternally.")
    train("duplicate_article_cleanup", "But the user also has to download The rewrite model from Hugging Face as well.", "But the user also has to download the rewrite model from Hugging Face as well.")
    train("invention_guard", "I hope you get good sleep though. Message me tomorrow.", "I hope you get good sleep though. Message me tomorrow.")
    train("uncertainty_preservation", "Yeah, I don't know if you know what you're doing, but let's stop this.", "Yeah, I don't know if you know what you're doing, but let's stop this.")
    train("pronoun_preservation", "Do you think now is a good time to call you?", "Do you think now is a good time to call you?")
    train("though_preservation", "That's cool. Are there any games that are your favorite besides the new ones that you've gotten though? Like anything you've played for a long time?", "That's cool. Are there any games that are your favorite besides the new ones that you've gotten though? Anything you've played for a long time?")

    # Nearby shapes for each failure mode.
    negation_cases = [
        ("I don't see how it can't be ready by Friday.", "I don't see how it can't be ready by Friday."),
        ("There's no way it can't happen if we keep pushing.", "There's no way it can't happen if we keep pushing."),
        ("I mean there is no way it can't be fixed before launch.", "There is no way it can't be fixed before launch."),
        ("There is no way this can fail if the backup works.", "There is no way this can fail if the backup works."),
        ("I don't think it can get any clearer than that.", "I don't think it can get any clearer than that."),
        ("There's no way it can get worse after that update.", "There's no way it can get worse after that update."),
    ]
    for user, assistant in negation_cases[:4]:
        train("negation_preservation", user, assistant)
    for user, assistant in negation_cases[4:5]:
        valid("negation_preservation", user, assistant)
    for user, assistant in negation_cases[5:]:
        test("negation_preservation", user, assistant)

    duplicate_article_cases = [
        ("The user also has to open The settings screen before syncing.", "The user also has to open the settings screen before syncing."),
        ("Please download The latest rewrite model from Hugging Face.", "Please download the latest rewrite model from Hugging Face."),
        ("They need to install The local model before using Vibes.", "They need to install the local model before using Vibes."),
        ("You have to select The polished adapter before running the test.", "You have to select the polished adapter before running the test."),
        ("The user needs to download the rewrite model from Hugging Face as well.", "The user needs to download the rewrite model from Hugging Face as well."),
        ("The app asks the user to download the Vibes model first.", "The app asks the user to download the Vibes model first."),
    ]
    for user, assistant in duplicate_article_cases[:4]:
        train("duplicate_article_cleanup", user, assistant)
    valid("duplicate_article_cleanup", *duplicate_article_cases[4])
    test("duplicate_article_cleanup", *duplicate_article_cases[5])

    invention_cases = [
        ("Hope you sleep well though. Text me tomorrow.", "Hope you sleep well though. Text me tomorrow."),
        ("I hope the meeting goes smoothly though. Call me after.", "I hope the meeting goes smoothly though. Call me after."),
        ("Get some rest tonight though. Message me when you're awake.", "Get some rest tonight though. Message me when you're awake."),
        ("I hope you feel better though. Let me know tomorrow.", "I hope you feel better though. Let me know tomorrow."),
        ("I hope you get good sleep tonight. Message me tomorrow.", "I hope you get good sleep tonight. Message me tomorrow."),
        ("I hope you get good sleep though. We can talk tomorrow.", "I hope you get good sleep though. We can talk tomorrow."),
    ]
    for user, assistant in invention_cases[:4]:
        train("invention_guard", user, assistant)
    valid("invention_guard", *invention_cases[4])
    test("invention_guard", *invention_cases[5])

    uncertainty_cases = [
        ("I don't know if you saw what happened, but we should pause this.", "I don't know if you saw what happened, but we should pause this."),
        ("I don't know if you know where this goes, but let's stop here.", "I don't know if you know where this goes, but let's stop here."),
        ("Yeah, I don't know if they know what they're doing, but we need to slow down.", "Yeah, I don't know if they know what they're doing, but we need to slow down."),
        ("I don't know what you're doing, but let's stop this.", "I don't know what you're doing, but let's stop this."),
        ("I don't know if you know who owns that, but don't delete it.", "I don't know if you know who owns that, but don't delete it."),
        ("I don't know if Sarah knows what changed, but we should ask.", "I don't know if Sarah knows what changed, but we should ask."),
    ]
    for user, assistant in uncertainty_cases[:4]:
        train("uncertainty_preservation", user, assistant)
    valid("uncertainty_preservation", *uncertainty_cases[4])
    test("uncertainty_preservation", *uncertainty_cases[5])

    pronoun_cases = [
        ("Is now a good time to call you?", "Is now a good time to call you?"),
        ("Do you want me to call you after lunch?", "Do you want me to call you after lunch?"),
        ("Would it be better if I call you tomorrow?", "Would it be better if I call you tomorrow?"),
        ("Can you call me when you get home?", "Can you call me when you get home?"),
        ("Do you think tonight is a good time to call you?", "Do you think tonight is a good time to call you?"),
        ("Would now be a bad time for me to call you?", "Would now be a bad time for me to call you?"),
    ]
    for user, assistant in pronoun_cases[:4]:
        train("pronoun_preservation", user, assistant)
    valid("pronoun_preservation", *pronoun_cases[4])
    test("pronoun_preservation", *pronoun_cases[5])

    though_cases = [
        ("Are there any books you still love though? Like anything you've reread for years?", "Are there any books you still love though? Anything you've reread for years?"),
        ("That's interesting. Have you tried the older version though? Like the one before this update?", "That's interesting. Have you tried the older version though? The one before this update?"),
        ("I get that. Is there anything else you want to keep though? Like any notes from the old draft?", "I get that. Is there anything else you want to keep though? Any notes from the old draft?"),
        ("The new games are fun, but do you still play the old ones though?", "The new games are fun, but do you still play the old ones though?"),
        ("Are there any songs you like besides the new ones though? Like anything from college?", "Are there any songs you like besides the new ones though? Anything from college?"),
        ("That's fair. Do you still want to try it though?", "That's fair. Do you still want to try it though?"),
    ]
    for user, assistant in though_cases[:4]:
        train("though_preservation", user, assistant)
    valid("though_preservation", *though_cases[4])
    test("though_preservation", *though_cases[5])

    # Small guard set from prior promoted behavior.
    guard_train_cases = [
        ("It feels like we've been doing this since twenty twelve, but it's only twenty eighteen.", "It feels like we've been doing this since 2012, but it's only 2018."),
        ("The team closed twenty two tickets, reviewed twenty eight screenshots, and ordered twenty five labels.", "The team closed 22 tickets, reviewed 28 screenshots, and ordered 25 labels."),
        ("And it's funny because all of those tools I had years ago came in handy to restore an eighteen year old pair of glasses.", "And it's funny because all of those tools I had years ago came in handy to restore an 18-year-old pair of glasses."),
        ("I would have spent a hundred dollars seven days ago.", "I would have spent $100 seven days ago."),
        ("I would have spent one hundred dollars seven days ago.", "I would have spent $100 seven days ago."),
        ("I would have spent fifty dollars seven days ago.", "I would have spent $50 seven days ago."),
        ("That should be a hundred euros.", "That should be €100."),
        ("That should be a hundred pounds.", "That should be £100."),
        ("That should be a hundred rupees.", "That should be ₹100."),
        ("I ended up getting ten for one dollar.", "I ended up getting 10 for $1."),
        ("I don't know, that's probably three dollars multiplied by four.", "That's probably $3 multiplied by four."),
        ("I don't know, that's probably 3 * 4 dollars.", "That's probably 3 * $4."),
        ("She said her address was eleven twenty five North Twelfth Street.", "She said her address was 1125 North 12th Street."),
        ("She said her address was eleven thirty seven North Twelfth Street.", "She said her address was 1137 North 12th Street."),
        ("That's probably five dollars multiplied by four.", "That's probably $5 multiplied by four."),
        ("That's probably three dollars multiplied by five.", "That's probably $3 multiplied by five."),
        ("That's probably seven dollars multiplied by four.", "That's probably $7 multiplied by four."),
        ("I don't know, that's probably 5 * 4 dollars.", "That's probably 5 * $4."),
        ("I don't know, that's probably 3 * 5 dollars.", "That's probably 3 * $5."),
        ("She said her address was twelve twenty five North Twelfth Street.", "She said her address was 1225 North 12th Street."),
        ("She said her address was ten forty two North Twelfth Street.", "She said her address was 1042 North 12th Street."),
    ]
    guard_valid_cases = [
        ("I probably spent a hundred dollars three days ago.", "I probably spent $100 three days ago."),
        ("I don't know, that's probably eight dollars multiplied by four.", "That's probably $8 multiplied by four."),
        ("She said her address was eleven forty eight North Twelfth Street.", "She said her address was 1148 North 12th Street."),
    ]
    guard_test_cases = [
        ("It probably cost a hundred dollars four days ago.", "It probably cost $100 four days ago."),
        ("I don't know, that's probably nine dollars multiplied by four.", "That's probably $9 multiplied by four."),
        ("She said her address was eleven fifty nine North Twelfth Street.", "She said her address was 1159 North 12th Street."),
    ]
    for user, assistant in guard_train_cases:
        train("live_regression_guard", user, assistant)
    for user, assistant in guard_valid_cases:
        valid("live_regression_guard", user, assistant)
    for user, assistant in guard_test_cases:
        test("live_regression_guard", user, assistant)

    live_prompt_compatibility_cases = [
        ("There was three things left on the checklist.", "There were three things left on the checklist."),
        ("I, I need the report by five.", "I need the report by five."),
        ("The budget is five thousand twenty two dollars, and the backup estimate is six thousand one hundred.", "The budget is $5,022, and the backup estimate is $6,100."),
        ("This is kind of annoying because um the button works once and then it like stops responding after the text changes.", "This is annoying because the button works once and then stops responding after the text changes."),
        ("Um remind me to order two cases of water, thirty six labels, and one hundred envelopes.", "Remind me to order two cases of water, 36 labels, and 100 envelopes."),
        ("I need groceries:\n\n1. Um apples\n2. Like two cartons of eggs\n3. Uh three bags of rice", "I need groceries:\n\n1. Apples\n2. two cartons of eggs\n3. three bags of rice"),
        ("I paid thirty two dollars and fifty cents for lunch, nine dollars for parking, and one hundred twenty dollars for the ticket.", "I paid $32.50 for lunch, $9 for parking, and $120 for the ticket."),
        ("Okay so for the roadmap, um, phase one is onboarding, phase two is billing, and phase three is the admin dashboard.", "For the roadmap, phase one is onboarding, phase two is billing, and phase three is the admin dashboard."),
        ("Please summarize this as a note for tomorrow. Um call the vendor at nine, confirm the order number four eight seven two, and ask whether delivery can happen before noon.", "Please summarize this as a note for tomorrow. Call the vendor at nine, confirm order number 4872, and ask whether delivery can happen before noon."),
        ("Okay, the customer said they tried the feature three times, um, the first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app.", "The customer said they tried the feature three times. The first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app."),
        ("For the internal recap, um, we shipped the first pass on Monday, reviewed twenty seven pieces of feedback on Tuesday, fixed the top five issues on Wednesday, and by Friday the average rewrite time had dropped from one point two seconds to zero point six seconds.", "For the internal recap, we shipped the first pass on Monday, reviewed 27 pieces of feedback on Tuesday, fixed the top five issues on Wednesday, and by Friday the average rewrite time had dropped from 1.2 seconds to 0.6 seconds."),
        ("Please clean this up for a client update. Um we are still waiting on the final assets, but engineering finished the integration, QA found two minor issues, and the earliest realistic ship date is June fifth unless the review takes longer than expected.", "Please clean this up for a client update: we are still waiting on the final assets, but engineering finished the integration, QA found two minor issues, and the earliest realistic ship date is June 5th unless the review takes longer than expected."),
        ("I bought that for four hundred and ninety nine dollars.", "I bought that for $499."),
        ("I bought that for three hundred and forty nine dollars.", "I bought that for $349."),
        ("The deposit was two hundred and seventy five euros.", "The deposit was €275."),
        ("The refund was four hundred and ninety nine pounds.", "The refund was £499."),
        ("The bill came to seven thousand four hundred dollars.", "The bill came to $7,400."),
        ("The quote was five thousand twenty two dollars.", "The quote was $5,022."),
        ("The backup estimate is six thousand one hundred dollars.", "The backup estimate is $6,100."),
    ]
    for user, assistant in live_prompt_compatibility_cases[:15]:
        train("live_prompt_compatibility", user, assistant)
    for user, assistant in live_prompt_compatibility_cases[15:17]:
        valid("live_prompt_compatibility", user, assistant)
    for user, assistant in live_prompt_compatibility_cases[17:]:
        test("live_prompt_compatibility", user, assistant)

    return examples


def write_split(examples: list[Example], split: str) -> int:
    records = [record(example.category, example.user, example.assistant) for example in examples if example.split == split]
    output_path = DATA_DIR / f"{split}.jsonl"
    with output_path.open("w", encoding="utf-8") as handle:
        for item in records:
            handle.write(json.dumps(item, ensure_ascii=False) + "\n")
    return len(records)


def main() -> int:
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    examples = build_examples()
    counts = {
        "train": write_split(examples, "train"),
        "valid": write_split(examples, "valid"),
        "test": write_split(examples, "test"),
    }

    category_counts = Counter(example.category for example in examples)
    manifest = {
        "version": "polished-alpha-027",
        "purpose": "continue polished alpha-026 with bad-rating meaning preservation guards",
        "source_bad_ratings": str(BAD_RATINGS_PATH.relative_to(MODEL_TRAINING_ROOT.parent)),
        "continued_from": "ModelTraining/artifacts/current/polished-lora-alpha-026/adapters/polished-alpha-026/adapters.safetensors",
        "train_count": counts["train"],
        "valid_count": counts["valid"],
        "test_count": counts["test"],
        "categories": dict(sorted(category_counts.items())),
        "bad_rating_records": load_bad_rating_summary(),
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
