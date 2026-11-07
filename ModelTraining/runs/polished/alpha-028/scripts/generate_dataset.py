#!/usr/bin/env python3
import importlib.util
import json
import sys
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "polished" / "alpha-028-continuation-casual-reductions"
REPORT_DIR = ROOT / "reports"
PROMPT = (MODEL_TRAINING_ROOT / "prompts" / "polished" / "polished_runtime_short.txt").read_text(encoding="utf-8").strip()
REPLAY_SCRIPT = MODEL_TRAINING_ROOT / "runs" / "polished" / "alpha-027" / "scripts" / "generate_dataset.py"
AINT_REPLAY_DIR = MODEL_TRAINING_ROOT / "datasets" / "polished" / "alpha-017-continuation-aint"
AINT_REPLAY_CATEGORIES = {"bad_grammar_aint", "bad_grammar_aint_context"}


@dataclass(frozen=True)
class Example:
    category: str
    user: str
    assistant: str
    split: str = "train"


def record(category: str, user: str, assistant: str) -> dict:
    return {
        "category": category,
        "messages": [
            {"role": "system", "content": PROMPT},
            {"role": "user", "content": user},
            {"role": "assistant", "content": assistant},
        ],
    }


REPLAY_CORRECTIONS = {
    "I need groceries:\n\n1. Um apples\n2. Like two cartons of eggs\n3. Uh three bags of rice": "I need groceries:\n\n1. Apples\n2. Two cartons of eggs\n3. Three bags of rice",
}


def load_replay_examples() -> list[Example]:
    spec = importlib.util.spec_from_file_location("polished_alpha_027_dataset", REPLAY_SCRIPT)
    module = importlib.util.module_from_spec(spec)
    sys.dont_write_bytecode = True
    spec.loader.exec_module(module)
    examples = [
        Example(
            example.category,
            example.user,
            REPLAY_CORRECTIONS.get(example.user, example.assistant),
            example.split,
        )
        for example in module.build_examples()
    ]
    corrected = {example.user for example in examples} & REPLAY_CORRECTIONS.keys()
    if corrected != REPLAY_CORRECTIONS.keys():
        raise ValueError(f"replay corrections did not match: {REPLAY_CORRECTIONS.keys() - corrected}")
    return examples


def load_aint_replay_examples() -> list[Example]:
    examples: list[Example] = []
    for split in ("train", "valid", "test"):
        with (AINT_REPLAY_DIR / f"{split}.jsonl").open("r", encoding="utf-8") as handle:
            for line in handle:
                item = json.loads(line)
                if item["category"] not in AINT_REPLAY_CATEGORIES:
                    continue
                messages = {message["role"]: message["content"] for message in item["messages"]}
                examples.append(Example(item["category"], messages["user"], messages["assistant"], split))
    return examples


GOTTA_CASES = [
    ("I gotta leave in a few minutes.", "I have to leave in a few minutes."),
    ("You gotta see the view from up here.", "You have to see the view from up here."),
    ("We gotta talk about the schedule before Monday.", "We have to talk about the schedule before Monday."),
    ("They gotta sign the lease by the end of the week.", "They have to sign the lease by the end of the week."),
    ("I've gotta finish the slides tonight.", "I've got to finish the slides tonight."),
    ("We've gotta get better at answering emails.", "We've got to get better at answering emails."),
    ("You've gotta tell me how that ended.", "You've got to tell me how that ended."),
    ("She's gotta be exhausted after that trip.", "She's got to be exhausted after that trip."),
    ("He's gotta know something we don't.", "He's got to know something we don't."),
    ("It's gotta be somewhere in the garage.", "It's got to be somewhere in the garage."),
    ("I gotta admit, that was pretty funny.", "I have to admit, that was pretty funny."),
    ("You don't gotta bring anything to the party.", "You don't have to bring anything to the party."),
    ("We don't gotta decide right now.", "We don't have to decide right now."),
    ("She doesn't gotta come if she's busy.", "She doesn't have to come if she's busy."),
    ("Do I gotta fill out this whole form?", "Do I have to fill out this whole form?"),
    ("Do we gotta wear suits to the dinner?", "Do we have to wear suits to the dinner?"),
    ("Why do you gotta make everything so complicated?", "Why do you have to make everything so complicated?"),
    ("What do I gotta do to get a refund?", "What do I have to do to get a refund?"),
    ("I really gotta get some sleep.", "I really have to get some sleep."),
    ("I just gotta send one more email and then I'm done.", "I just have to send one more email, and then I'm done."),
    ("Honestly, you gotta stop worrying about it.", "Honestly, you have to stop worrying about it."),
    ("If we're doing this, we gotta do it right.", "If we're doing this, we have to do it right."),
    ("I gotta call my mom back before dinner.", "I have to call my mom back before dinner."),
    ("You gotta be kidding me right now.", "You have to be kidding me right now."),
    ("We gotta get the car inspected this month.", "We have to get the car inspected this month."),
    ("They gotta fix that pothole on our street.", "They have to fix that pothole on our street."),
    ("I gotta pick up a few things from the pharmacy.", "I have to pick up a few things from the pharmacy."),
    ("Gotta go, my ride is here.", "Have to go, my ride is here."),
    ("Gotta finish this chapter before bed.", "Have to finish this chapter before bed."),
    ("Gotta head out, see you later.", "Have to head out, see you later."),
    ("Gotta jump on a call, text you after.", "Have to jump on a call, text you after."),
    ("Gotta leave now, I'll call you tonight.", "Have to leave now, I'll call you tonight."),
    ("Gotta get back to work, talk later.", "Have to get back to work, talk later."),
    ("Gotta wake up early tomorrow.", "Have to wake up early tomorrow."),
    ("I gotta problem with my car.", "I have a problem with my car."),
    ("We gotta situation at the office.", "We have a situation at the office."),
    ("You gotta pen I can borrow?", "You have a pen I can borrow?"),
    ("I gotta question about the invoice.", "I have a question about the invoice."),
    ("She gotta new puppy last week.", "She got a new puppy last week."),
    ("He gotta work late again tonight.", "He has to work late again tonight."),
    ("She gotta be at the airport early.", "She has to be at the airport early."),
    ("I gotta feeling this is going to work.", "I have a feeling this is going to work."),
    ("You gotta minute to look at this?", "You have a minute to look at this?"),
    ("I gotta get going.", "I have to get going."),
    ("We gotta remember to water the plants.", "We have to remember to water the plants."),
    ("We gotta stop meeting like this.", "We have to stop meeting like this."),
    ("I gotta run to the bank before it closes.", "I have to run to the bank before it closes."),
    ("Do you gotta work this weekend?", "Do you have to work this weekend?"),
]

GONNA_CASES = [
    ("Gonna head out early today.", "Going to head out early today."),
    ("Gonna need your help with the move on Saturday.", "Going to need your help with the move on Saturday."),
    ("Gonna try the new place downtown tonight.", "Going to try the new place downtown tonight."),
    ("Y'all gonna watch the game tonight?", "Y'all going to watch the game tonight?"),
    ("You guys gonna come to the barbecue?", "You guys going to come to the barbecue?"),
    ("When are you gonna be home?", "When are you going to be home?"),
    ("How are we gonna get all of this done?", "How are we going to get all of this done?"),
    ("Who's gonna tell him?", "Who's going to tell him?"),
    ("It's not gonna fit in the trunk.", "It's not going to fit in the trunk."),
    ("This is gonna be the best summer ever.", "This is going to be the best summer ever."),
    ("I'm gonna be honest, I forgot.", "I'm going to be honest, I forgot."),
    ("She's gonna call you back after her meeting.", "She's going to call you back after her meeting."),
    ("You're not gonna believe what happened at work.", "You're not going to believe what happened at work."),
    ("We were gonna leave, but it started snowing.", "We were going to leave, but it started snowing."),
    ("If it's gonna rain, let's reschedule.", "If it's going to rain, let's reschedule."),
    ("Things are gonna get better, I promise.", "Things are going to get better, I promise."),
    ("Is anyone gonna eat the last slice?", "Is anyone going to eat the last slice?"),
    ("Gonna be a long night.", "Going to be a long night."),
    ("Where are you gonna park?", "Where are you going to park?"),
]

WANNA_CASES = [
    ("Wanna grab dinner after work?", "Want to grab dinner after work?"),
    ("Wanna see the pictures from the trip?", "Want to see the pictures from the trip?"),
    ("Wanna split an appetizer?", "Want to split an appetizer?"),
    ("Where do you wanna go for vacation?", "Where do you want to go for vacation?"),
    ("What do you wanna do this weekend?", "What do you want to do this weekend?"),
    ("How do you wanna handle the invitations?", "How do you want to handle the invitations?"),
    ("Which one do you wanna keep?", "Which one do you want to keep?"),
    ("When do you wanna leave?", "When do you want to leave?"),
    ("I just wanna sleep for a whole day.", "I just want to sleep for a whole day."),
    ("We don't wanna be late again.", "We don't want to be late again."),
    ("He doesn't wanna talk to anyone today.", "He doesn't want to talk to anyone today."),
    ("Do you wanna drink?", "Do you want to drink?"),
    ("I wanna new phone for my birthday.", "I want a new phone for my birthday."),
    ("You wanna know the funny part?", "You want to know the funny part?"),
    ("If they wanna come, they can.", "If they want to come, they can."),
    ("I never wanna do that again.", "I never want to do that again."),
    ("Wanna come with us to the lake?", "Want to come with us to the lake?"),
    ("Why do you wanna quit?", "Why do you want to quit?"),
]

OTHER_REDUCTION_CASES = [
    ("Lemme check my calendar and get back to you.", "Let me check my calendar and get back to you."),
    ("Lemme think about it overnight.", "Let me think about it overnight."),
    ("Can you lemme know when you land?", "Can you let me know when you land?"),
    ("Gimme a second to find it.", "Give me a second to find it."),
    ("Can you gimme a hand with these boxes?", "Can you give me a hand with these boxes?"),
    ("I'm kinda nervous about the interview.", "I'm kind of nervous about the interview."),
    ("It's kinda cold in here.", "It's kind of cold in here."),
    ("That was sorta what I expected.", "That was sort of what I expected."),
    ("I sorta forgot to reply.", "I sort of forgot to reply."),
    ("We ran outta milk again.", "We ran out of milk again."),
    ("I need to get outta this meeting.", "I need to get out of this meeting."),
    ("I dunno where I left my keys.", "I don't know where I left my keys."),
    ("Dunno if I can make it tonight.", "Don't know if I can make it tonight."),
    ("We hafta be there by noon.", "We have to be there by noon."),
    ("That's a lotta food for two people.", "That's a lot of food for two people."),
    ("There's a lotta traffic on the highway.", "There's a lot of traffic on the highway."),
    ("See ya tomorrow.", "See you tomorrow."),
    ("Thank ya for the help.", "Thank you for the help."),
    ("Lemme see that for a second.", "Let me see that for a second."),
    ("Gimme a call when you're free.", "Give me a call when you're free."),
]

MIXED_CASES = [
    ("I gotta work late, but I wanna see you this weekend, so I'm gonna call you tomorrow.", "I have to work late, but I want to see you this weekend, so I'm going to call you tomorrow."),
    ("Um, so we gotta pick a venue, and I'm gonna, like, call a few places tomorrow.", "We have to pick a venue, and I'm going to call a few places tomorrow."),
    ("Hey, you wanna get lunch? I gotta be back by one though.", "Hey, you want to get lunch? I have to be back by one though."),
    ("I'm gonna be straight with you. We gotta cut the budget, and nobody's gonna like it.", "I'm going to be straight with you. We have to cut the budget, and nobody's going to like it."),
    ("Hi Dana, I wanted to let you know I gotta move our call. I'm gonna be at the dentist, so lemme know what works for you.", "Hi Dana, I wanted to let you know I have to move our call. I'm going to be at the dentist, so let me know what works for you."),
    ("Okay so first we gotta clean the garage. Then I wanna paint the fence.\n\nAfter that we're gonna relax, I promise. You gotta trust me on this.", "First we have to clean the garage. Then I want to paint the fence.\n\nAfter that we're going to relax, I promise. You have to trust me on this."),
    ("I dunno, I kinda wanna stay in tonight.", "I don't know, I kind of want to stay in tonight."),
    ("Gotta be honest, I'm gonna miss this place.", "Have to be honest, I'm going to miss this place."),
    ("If you wanna help, you gotta show up early, and I'm gonna need you all day.", "If you want to help, you have to show up early, and I'm going to need you all day."),
    ("I wanna say yes, I really do, but I gotta check with my wife first.", "I want to say yes, I really do, but I have to check with my wife first."),
    ("We gotta leave soon, so if you wanna shower, you're gonna have to hurry.", "We have to leave soon, so if you want to shower, you're going to have to hurry."),
    ("I'm not gonna lie, I kinda wanna skip the party, but I gotta show up.", "I'm not going to lie, I kind of want to skip the party, but I have to show up."),
]

MEANING_GUARD_CASES = [
    ("We gotta stop at the gas station on the way.", "We have to stop at the gas station on the way."),
    ("You gotta stop by the office sometime.", "You have to stop by the office sometime."),
    ("Ya know what I mean?", "You know what I mean?"),
    ("I gotta be honest, I really do love it.", "I have to be honest, I really do love it."),
    ("I'm not gonna go, and I don't wanna be asked again.", "I'm not going to go, and I don't want to be asked again."),
    ("I wasn't gonna say anything, but you gotta know.", "I wasn't going to say anything, but you have to know."),
    ("I'm not gonna call and I'm not gonna text.", "I'm not going to call, and I'm not going to text."),
    ("She's gonna cook and I wanna clean up.", "She's going to cook, and I want to clean up."),
    ("We gotta pack and we gotta leave by noon.", "We have to pack, and we have to leave by noon."),
    ("I don't wanna argue and I don't wanna wait.", "I don't want to argue, and I don't want to wait."),
    ("Anyway, I'm gonna get some rest.", "Anyway, I'm going to get some rest."),
    ("Anyway, we gotta decide by tomorrow.", "Anyway, we have to decide by tomorrow."),
    ("That's the whole story.\n\nAnyway, if you wanna talk more, call me.", "That's the whole story.\n\nAnyway, if you want to talk more, call me."),
]

FILLER_LIST_GUARD_CASES = [
    ("Please call the bank, like ask about the fee, and then email me.", "Please call the bank, ask about the fee, and then email me."),
    ("Can you pack the car, like grab the cooler, and lock the house?", "Can you pack the car, grab the cooler, and lock the house?"),
    ("We should book the hotel, like reserve the van, and confirm the tickets.", "We should book the hotel, reserve the van, and confirm the tickets."),
    ("Make sure you water the plants, like feed the cat, and take out the trash.", "Make sure you water the plants, feed the cat, and take out the trash."),
]

CONTROL_CASES = [
    ("I'm going to the gym after work.", "I'm going to the gym after work."),
    ("We've got to leave by noon.", "We've got to leave by noon."),
    ("I got a new job last week.", "I got a new job last week."),
    ("I want to thank everyone for coming.", "I want to thank everyone for coming."),
    ("I have to finish the report tonight.", "I have to finish the report tonight."),
    ("It's kind of a long story.", "It's kind of a long story."),
    ("Let me know if you need anything else.", "Let me know if you need anything else."),
    ("You know what I mean?", "You know what I mean?"),
    ("I got to meet the band after the show.", "I got to meet the band after the show."),
    ("I don't know what happened.", "I don't know what happened."),
    ("We're going to need more chairs.", "We're going to need more chairs."),
    ("Give me a call when you get a chance.", "Give me a call when you get a chance."),
]

NEW_CASE_GROUPS = [
    ("casual_reduction_gotta", GOTTA_CASES),
    ("casual_reduction_gonna", GONNA_CASES),
    ("casual_reduction_wanna", WANNA_CASES),
    ("casual_reduction_other", OTHER_REDUCTION_CASES),
    ("casual_reduction_mixed", MIXED_CASES),
    ("casual_reduction_meaning_guard", MEANING_GUARD_CASES),
    ("filler_list_guard", FILLER_LIST_GUARD_CASES),
    ("casual_reduction_control", CONTROL_CASES),
]


def build_examples() -> list[Example]:
    examples: list[Example] = []
    seen: set[str] = set()

    def add(example: Example) -> None:
        if example.user in seen:
            raise ValueError(f"duplicate user example: {example.user}")
        seen.add(example.user)
        examples.append(example)

    for category, cases in NEW_CASE_GROUPS:
        held_out = 2 if len(cases) >= 10 else 0
        train_cases = cases[: len(cases) - held_out]
        for user, assistant in train_cases:
            add(Example(category, user, assistant, "train"))
        if held_out:
            add(Example(category, *cases[-2], "valid"))
            add(Example(category, *cases[-1], "test"))

    for example in load_replay_examples():
        add(example)

    for example in load_aint_replay_examples():
        add(example)

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
        "version": "polished-alpha-028",
        "purpose": "continue polished alpha-027 with casual spoken reductions written out in standard form",
        "replayed_from": [
            str(REPLAY_SCRIPT.relative_to(MODEL_TRAINING_ROOT.parent)),
            str(AINT_REPLAY_DIR.relative_to(MODEL_TRAINING_ROOT.parent)),
        ],
        "continued_from": "ModelTraining/artifacts/current/polished-lora-alpha-027/adapters/polished-alpha-027/adapters.safetensors",
        "train_count": counts["train"],
        "valid_count": counts["valid"],
        "test_count": counts["test"],
        "categories": dict(sorted(category_counts.items())),
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
