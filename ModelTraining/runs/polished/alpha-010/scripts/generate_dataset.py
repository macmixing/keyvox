#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "polished" / "alpha-010-base"
REPORT_DIR = ROOT / "reports"
SYSTEM_PROMPT = (
    MODEL_TRAINING_ROOT / "prompts" / "polished" / "polished_runtime_short.txt"
).read_text(encoding="utf-8").strip()
TRAIN_COUNT = 8_000
VALID_COUNT = 800
TEST_COUNT = 800
TOTAL_COUNT = TRAIN_COUNT + VALID_COUNT + TEST_COUNT


@dataclass(frozen=True)
class Example:
    category: str
    user: str
    assistant: str


FILLERS = ["um", "uh", "er", "uh-huh", "hm", "hmm", "you know", "I mean"]
NAMES = ["Alex", "Jordan", "Maria", "Sam", "Taylor", "Chris", "Priya", "Morgan", "Riley", "Jamie"]
OBJECTS = ["invoice", "build", "deck", "brief", "contract", "screenshot", "demo", "outline", "report", "prototype"]
TOPICS = [
    "the keyboard",
    "the onboarding flow",
    "the subscription screen",
    "the launch checklist",
    "the dictation model",
    "the settings page",
    "the support message",
    "the release notes",
    "the billing issue",
    "the calendar invite",
    "the app review response",
    "the customer email",
]
TIMES = [("five", "5"), ("three thirty", "3:30"), ("twelve thirty", "12:30"), ("six fifteen", "6:15"), ("nine", "9")]
MONEY = [
    ("thirty five dollars", "$35"),
    ("twelve dollars", "$12"),
    ("one hundred twenty dollars", "$120"),
    ("nine dollars", "$9"),
    ("thirty two dollars and fifty cents", "$32.50"),
    ("five thousand twenty two dollars", "$5,022"),
    ("six thousand one hundred dollars", "$6,100"),
    ("one thousand one hundred four dollars", "$1,104"),
]
NUMBER_PHRASES = [
    ("five hundred", "500"),
    ("one hundred", "100"),
    ("one hundred seats", "100 seats"),
    ("one hundred envelopes", "100 envelopes"),
    ("one hundred units", "100 units"),
    ("one hundred twenty", "120"),
    ("two hundred sixteen", "216"),
    ("twenty twenty four", "2024"),
    ("twenty twenty five", "2025"),
    ("twenty twenty six", "2026"),
    ("nineteen ninety nine", "1999"),
    ("two thousand six", "2006"),
    ("five thousand twenty two", "5,022"),
    ("six thousand one hundred", "6,100"),
    ("twelve hundred", "1,200"),
    ("one thousand five hundred", "1,500"),
    ("one thousand two hundred", "1,200"),
    ("one thousand one hundred four", "1,104"),
    ("ten thousand", "10,000"),
    ("one million two hundred thousand", "1,200,000"),
]
MEASUREMENTS = [
    ("five inches", "5 inches"),
    ("twelve miles", "12 miles"),
    ("three percent", "3%"),
    ("fifteen percent", "15%"),
    ("twenty five percent", "25%"),
    ("twelve point five percent", "12.5%"),
    ("one point two seconds", "1.2 seconds"),
    ("zero point six seconds", "0.6 seconds"),
]


def record(example: Example) -> dict:
    return {
        "category": example.category,
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": example.user},
            {"role": "assistant", "content": example.assistant},
        ],
    }


def add_unique(examples: list[Example], seen: set[str], example: Example) -> None:
    if example.user in seen:
        return
    seen.add(example.user)
    examples.append(example)


def filler_examples() -> list[Example]:
    examples = []
    seen = set()
    for filler in FILLERS:
        add_unique(examples, seen, Example("filler_removal", f"{filler.capitalize()}, can you send the {OBJECTS[0]} today?", f"Can you send the {OBJECTS[0]} today?"))
        add_unique(examples, seen, Example("filler_removal", f"Can you {filler} send the {OBJECTS[1]} to {NAMES[0]}?", f"Can you send the {OBJECTS[1]} to {NAMES[0]}?"))
        add_unique(examples, seen, Example("filler_after_punctuation", f"We made it. {filler.capitalize()}, please send the {OBJECTS[2]}.", f"We made it. Please send the {OBJECTS[2]}."))
        add_unique(examples, seen, Example("filler_after_punctuation", f"Is everything okay? {filler.capitalize()}, are you still having trouble?", "Is everything okay? Are you still having trouble?"))
        add_unique(examples, seen, Example("meaning_preservation", f"I don't know why, {filler}, this keeps happening.", "I don't know why this keeps happening."))
    for name in NAMES:
        add_unique(examples, seen, Example("filler_removal", f"Hey {name}, um, can you check this when you get a second?", f"Hey {name}, can you check this when you get a second?"))
        add_unique(examples, seen, Example("filler_removal", f"Uh can you remind {name} about the meeting?", f"Can you remind {name} about the meeting?"))
    for obj in OBJECTS:
        add_unique(examples, seen, Example("filler_removal", f"I need to, like, finish the {obj} before tomorrow.", f"I need to finish the {obj} before tomorrow."))
        add_unique(examples, seen, Example("filler_after_punctuation", f"This is ready. Hmm, can you review the {obj}?", f"This is ready. Can you review the {obj}?"))
    return examples


def rambly_filler_examples() -> list[Example]:
    seeds = [
        (
            "Okay, so we're just gonna talk for a little bit and um like just try to figure some things out and see exactly how like you know um this dictation works because I wanna dictate something polished.",
            "Okay, so we're going to talk for a little bit and try to figure some things out, including how this dictation works, because I want to dictate something polished.",
        ),
        (
            "Okay, hold on, wait. Um, I think like this might have like um probably made a huge difference.",
            "Okay, hold on, wait. I think this might have made a huge difference.",
        ),
        (
            "Hey, um like what are you um doing later if you like I don't know, you know. You know what I mean?",
            "Hey, what are you doing later? You know what I mean?",
        ),
        (
            "So I guess um what I'm trying to say is like we should probably wait until tomorrow because you know the build is still acting weird.",
            "So I guess what I'm trying to say is that we should probably wait until tomorrow because the build is still acting weird.",
        ),
        (
            "I mean I don't know if this is the right call but um like I think we need to test it on the phone before we decide.",
            "I don't know if this is the right call, but I think we need to test it on the phone before we decide.",
        ),
        (
            "Hey, um, can you like take a look at this when you get a second because I think you know it might be broken again.",
            "Hey, can you take a look at this when you get a second? I think it might be broken again.",
        ),
        (
            "Okay so um the thing is I was trying to finish the report and like the numbers kept changing and you know I don't want to send the wrong version.",
            "Okay, so the thing is, I was trying to finish the report, but the numbers kept changing, and I don't want to send the wrong version.",
        ),
        (
            "I think like if we can get this done today then um we can probably ship the update tomorrow without making it feel rushed.",
            "I think if we can get this done today, we can probably ship the update tomorrow without making it feel rushed.",
        ),
        (
            "Can you um maybe check the screenshot and like tell me if the button looks weird because I keep staring at it and I can't tell anymore.",
            "Can you check the screenshot and tell me if the button looks weird? I keep staring at it, and I can't tell anymore.",
        ),
        (
            "So this is kind of annoying but um I think the keyboard is doing the right thing now and like we just need to verify the edge cases.",
            "So this is kind of annoying, but I think the keyboard is doing the right thing now, and we just need to verify the edge cases.",
        ),
        (
            "I was gonna send this earlier but um like I got pulled into another call and you know I forgot to come back to it.",
            "I was going to send this earlier, but I got pulled into another call and forgot to come back to it.",
        ),
        (
            "Okay um please don't overthink this but like I need the message to sound polished and still sound like I wrote it.",
            "Okay, please don't overthink this, but I need the message to sound polished and still sound like I wrote it.",
        ),
        (
            "I mean honestly this is probably fine but um I want one more pass because like the tone still feels a little off.",
            "Honestly, this is probably fine, but I want one more pass because the tone still feels a little off.",
        ),
    ]
    examples = [Example("rambly_filler_cleanup", user, assistant) for user, assistant in seeds]
    topics = [
        ("the onboarding flow", "too abrupt"),
        ("the settings screen", "a little crowded"),
        ("the keyboard animation", "slightly delayed"),
        ("the pricing copy", "too vague"),
        ("the release notes", "too long"),
        ("the demo", "almost ready"),
        ("the prototype", "closer than I expected"),
        ("the prompt", "not specific enough"),
    ]
    for topic, concern in topics:
        examples.append(Example(
            "rambly_filler_cleanup",
            f"Okay so um I was looking at {topic} and like I think it's {concern} but you know we can probably fix it with one more pass.",
            f"Okay, so I was looking at {topic}, and I think it's {concern}, but we can probably fix it with one more pass.",
        ))
        examples.append(Example(
            "rambly_filler_cleanup",
            f"I don't know maybe this is too much but um like can you check {topic} and tell me if it feels {concern}.",
            f"I don't know, maybe this is too much, but can you check {topic} and tell me if it feels {concern}?",
        ))
    return examples


def short_message_examples() -> list[Example]:
    seeds = [
        ("Um yes please.", "Yes, please."),
        ("Uh no thanks.", "No, thanks."),
        ("Like can you call me?", "Can you call me?"),
        ("I mean maybe later.", "Maybe later."),
        ("Hmm I don't know yet.", "I don't know yet."),
        ("You know I think so.", "I think so."),
        ("Okay um sure.", "Okay, sure."),
        ("Wait uh what happened?", "Wait, what happened?"),
        ("Hey um are you free?", "Hey, are you free?"),
        ("Yeah like that works.", "Yeah, that works."),
    ]
    return [Example("short_filler_cleanup", user, assistant) for user, assistant in seeds]


def long_paragraph_examples() -> list[Example]:
    examples = []
    templates = [
        (
            "Okay so um I was looking at {topic} this morning and like I think the main issue is that it feels close but not finished yet and you know I don't want to ship something that creates more questions for people.",
            "Okay, so I was looking at {topic} this morning, and I think the main issue is that it feels close but not finished yet. I don't want to ship something that creates more questions for people.",
        ),
        (
            "I mean the thing I'm trying to explain is that {topic} is probably fine for now but um we should still test it one more time because like the edge cases are where this usually breaks.",
            "The thing I'm trying to explain is that {topic} is probably fine for now, but we should still test it one more time because the edge cases are where this usually breaks.",
        ),
        (
            "So um if you get a chance later can you look at {topic} and tell me whether it sounds too intense because like I want it to be clear without making it feel harsh.",
            "So, if you get a chance later, can you look at {topic} and tell me whether it sounds too intense? I want it to be clear without making it feel harsh.",
        ),
        (
            "I'm not saying we need to redo {topic} but um I do think we should tighten the wording because you know people are going to skim this and we need the point to land quickly.",
            "I'm not saying we need to redo {topic}, but I do think we should tighten the wording because people are going to skim this, and we need the point to land quickly.",
        ),
    ]
    for topic in TOPICS:
        for user_template, assistant_template in templates:
            examples.append(Example(
                "long_rambly_cleanup",
                user_template.format(topic=topic),
                assistant_template.format(topic=topic),
            ))
    return examples


def email_note_examples() -> list[Example]:
    examples = []
    seeds = [
        (
            "Hey Alex um I looked at the deck and like I think slide three needs one more pass before we send it.",
            "Hey Alex, I looked at the deck, and I think slide 3 needs one more pass before we send it.",
        ),
        (
            "Hi Maria I mean I can make the call but um I might be five minutes late.",
            "Hi Maria, I can make the call, but I might be 5 minutes late.",
        ),
        (
            "Jordan um thanks for sending this over I will review it tonight and get back to you tomorrow.",
            "Jordan, thanks for sending this over. I will review it tonight and get back to you tomorrow.",
        ),
        (
            "Sam can you like send me the final invoice for five hundred dollars when you get a chance?",
            "Sam, can you send me the final invoice for $500 when you get a chance?",
        ),
    ]
    for user, assistant in seeds:
        examples.append(Example("email_note_cleanup", user, assistant))
    return examples


def question_request_examples() -> list[Example]:
    examples = []
    actions = [
        ("check the build", "check the build"),
        ("send the invoice", "send the invoice"),
        ("review the screenshots", "review the screenshots"),
        ("move the meeting", "move the meeting"),
        ("update the release notes", "update the release notes"),
        ("look at the crash report", "look at the crash report"),
    ]
    for spoken, written in actions:
        examples.append(Example("question_request_cleanup", f"Can you um {spoken} when you get a second?", f"Can you {written} when you get a second?"))
        examples.append(Example("question_request_cleanup", f"Hey, uh, could you {spoken} before five?", f"Hey, could you {written} before 5?"))
        examples.append(Example("question_request_cleanup", f"I mean can you like please {spoken} today?", f"Can you please {written} today?"))
        examples.append(Example("question_request_cleanup", f"Do you know if you can {spoken} by twenty twenty five?", f"Do you know if you can {written} by 2025?"))
    return examples


def structured_number_examples() -> list[Example]:
    return [
        Example(
            "structure_preservation",
            "I need three things:\n\n1. Um the invoice for five hundred dollars\n2. The deck by three thirty\n3. Uh the signup count from twenty twenty four",
            "I need three things:\n\n1. The invoice for $500\n2. The deck by 3:30\n3. The signup count from 2024",
        ),
        Example(
            "structure_preservation",
            "Please check:\n\n- um login at nine\n- pricing at twelve thirty\n- like screenshots from May third",
            "Please check:\n\n- Login at 9\n- Pricing at 12:30\n- Screenshots from May 3rd",
        ),
        Example(
            "structure_preservation",
            "The numbers are:\n\n1. five hundred users\n2. twenty five percent conversion\n3. thirty five dollars per month",
            "The numbers are:\n\n1. 500 users\n2. 25% conversion\n3. $35 per month",
        ),
    ]


def punctuation_examples() -> list[Example]:
    seeds = [
        ("No I don't think that's what I meant.", "No, I don't think that's what I meant."),
        ("Actually can you ignore that last message?", "Actually, can you ignore that last message?"),
        ("Thanks for helping with this I really appreciate it.", "Thanks for helping with this. I really appreciate it."),
        ("I'm sorry I missed this earlier I was in meetings all day.", "I'm sorry I missed this earlier. I was in meetings all day."),
        ("The login screen is broken on iPad but it works on iPhone.", "The login screen is broken on iPad, but it works on iPhone."),
        ("This is not urgent but I wanted to flag it now.", "This is not urgent, but I wanted to flag it now."),
        ("I am not mad I just need this fixed today.", "I am not mad. I just need this fixed today."),
        ("The app feels really close now it just needs a little more tuning.", "The app feels really close now. It just needs a little more tuning."),
        ("Please don't change the wording too much I just want it cleaned up.", "Please don't change the wording too much. I just want it cleaned up."),
        ("This looks good overall just fix the last paragraph.", "This looks good overall. Just fix the last paragraph."),
    ]
    return [Example("punctuation_repair", user, assistant) for user, assistant in seeds]


def number_examples() -> list[Example]:
    examples = []
    for spoken, written in TIMES:
        examples.append(Example("number_repair", f"Please call me at {spoken} if this is still broken.", f"Please call me at {written} if this is still broken."))
        examples.append(Example("number_repair", f"The meeting is at {spoken} on Tuesday.", f"The meeting is at {written} on Tuesday."))
    for spoken, written in MONEY:
        examples.append(Example("number_repair", f"Can you send {spoken} for lunch?", f"Can you send {written} for lunch?"))
        examples.append(Example("number_repair", f"The refund should be {spoken}.", f"The refund should be {written}."))
    date_pairs = [("May third", "May 3rd"), ("June first", "June 1st"), ("October twenty second", "October 22nd")]
    for spoken, written in date_pairs:
        examples.append(Example("number_repair", f"Let's meet on {spoken}.", f"Let's meet on {written}."))
        examples.append(Example("number_repair", f"The deadline is {spoken} at three thirty.", f"The deadline is {written} at 3:30."))
    for spoken, written in NUMBER_PHRASES:
        examples.append(Example("number_repair", f"We need about {spoken} users before this result means anything.", f"We need about {written} users before this result means anything."))
        examples.append(Example("number_repair", f"The count was {spoken} yesterday.", f"The count was {written} yesterday."))
        examples.append(Example("number_repair", f"Can you put {spoken} in the summary?", f"Can you put {written} in the summary?"))
    for spoken, written in MEASUREMENTS:
        examples.append(Example("number_repair", f"The gap is about {spoken}.", f"The gap is about {written}."))
        examples.append(Example("number_repair", f"I think it improved by {spoken}.", f"I think it improved by {written}."))
    mixed = [
        ("In twenty twenty four we had five hundred signups.", "In 2024, we had 500 signups."),
        ("The total should be five thousand twenty two not five hundred.", "The total should be 5,022, not 500."),
        ("I spent thirty five dollars and got twelve items.", "I spent $35 and got 12 items."),
        ("Schedule it for June first at three thirty.", "Schedule it for June 1st at 3:30."),
        ("The goal is one thousand five hundred users by twenty twenty five.", "The goal is 1,500 users by 2025."),
        ("It was about twenty five percent faster after the change.", "It was about 25% faster after the change."),
    ]
    for user, assistant in mixed:
        examples.append(Example("number_repair", user, assistant))
    return examples


def numeric_stress_examples() -> list[Example]:
    examples = []
    quantity_pairs = [
        ("two cases of water", "2 cases of water"),
        ("thirty six labels", "36 labels"),
        ("one hundred envelopes", "100 envelopes"),
        ("one hundred seats", "100 seats"),
        ("two hundred sixteen units", "216 units"),
        ("twenty seven pieces of feedback", "27 pieces of feedback"),
        ("top five issues", "top 5 issues"),
        ("three times", "3 times"),
        ("two minor issues", "2 minor issues"),
        ("forty eight boxes", "48 boxes"),
        ("twelve boxes", "12 boxes"),
    ]
    contexts = [
        ("Please write down", "."),
        ("Can you confirm", "?"),
        ("The update should mention", "."),
        ("For the note, include", "."),
        ("In the summary, keep", "."),
    ]
    for spoken, written in quantity_pairs:
        for prefix, suffix in contexts:
            examples.append(Example("numeric_stress", f"{prefix} {spoken}{suffix}", f"{prefix} {written}{suffix}"))
            examples.append(Example("numeric_stress", f"Um {prefix.lower()} {spoken}{suffix}", f"{prefix} {written}{suffix}"))

    examples.extend([
        Example(
            "numeric_stress",
            "The budget is five thousand twenty two dollars, and the backup estimate is six thousand one hundred.",
            "The budget is $5,022, and the backup estimate is $6,100.",
        ),
        Example(
            "numeric_stress",
            "Um remind me to order two cases of water, thirty six labels, and one hundred envelopes.",
            "Remind me to order 2 cases of water, 36 labels, and 100 envelopes.",
        ),
        Example(
            "numeric_stress",
            "I paid thirty two dollars and fifty cents for lunch, nine dollars for parking, and one hundred twenty dollars for the ticket.",
            "I paid $32.50 for lunch, $9 for parking, and $120 for the ticket.",
        ),
        Example(
            "numeric_stress",
            "Can you write this down? Um the first option is fifteen seats, the second option is twenty five seats, and the enterprise plan starts at one hundred seats.",
            "Can you write this down? The first option is 15 seats, the second option is 25 seats, and the enterprise plan starts at 100 seats.",
        ),
        Example(
            "numeric_stress",
            "For the invoice, um, the subtotal is one thousand two hundred dollars, the discount is fifteen percent, tax is eighty four dollars, and the final total should be one thousand one hundred four dollars.",
            "For the invoice, the subtotal is $1,200, the discount is 15%, tax is $84, and the final total should be $1,104.",
        ),
        Example(
            "numeric_stress",
            "Okay, the customer said they tried the feature three times, um, the first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app.",
            "The customer said they tried the feature 3 times. The first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app.",
        ),
        Example(
            "numeric_stress",
            "For the internal recap, um, we shipped the first pass on Monday, reviewed twenty seven pieces of feedback on Tuesday, fixed the top five issues on Wednesday, and by Friday the average rewrite time had dropped from one point two seconds to zero point six seconds.",
            "For the internal recap, we shipped the first pass on Monday, reviewed 27 pieces of feedback on Tuesday, fixed the top 5 issues on Wednesday, and by Friday the average rewrite time had dropped from 1.2 seconds to 0.6 seconds.",
        ),
        Example(
            "numeric_stress",
            "Please clean this up for a client update. Um we are still waiting on the final assets, but engineering finished the integration, QA found two minor issues, and the earliest realistic ship date is June fifth unless the review takes longer than expected.",
            "Please clean this up for a client update: we are still waiting on the final assets, but engineering finished the integration, QA found 2 minor issues, and the earliest realistic ship date is June 5th unless the review takes longer than expected.",
        ),
        Example(
            "numeric_stress",
            "Turn this into a clean note. Um the warehouse has twelve boxes ready now, another forty eight boxes arriving next week, and a back order of two hundred sixteen units that should arrive in twenty twenty six.",
            "Turn this into a clean note: the warehouse has 12 boxes ready now, another 48 boxes arriving next week, and a back order of 216 units that should arrive in 2026.",
        ),
        Example(
            "numeric_stress",
            "Revenue was up twelve point five percent, but churn went down by three percent.",
            "Revenue was up 12.5%, but churn went down by 3%.",
        ),
    ])
    return examples


def repeat_examples() -> list[Example]:
    seeds = [
        ("I I think we should wait until tomorrow.", "I think we should wait until tomorrow."),
        ("Can you can you call me when you get this?", "Can you call me when you get this?"),
        ("The the problem is in the keyboard extension.", "The problem is in the keyboard extension."),
        ("I was I was trying to explain the issue.", "I was trying to explain the issue."),
        ("Can we can we move the call to Friday?", "Can we move the call to Friday?"),
        ("This this is probably good enough for now.", "This is probably good enough for now."),
        ("I need I need the final version today.", "I need the final version today."),
        ("Please please check this before you send it.", "Please check this before you send it."),
    ]
    return [Example("repeated_start", user, assistant) for user, assistant in seeds]


def structure_examples() -> list[Example]:
    examples = []
    lists = [
        ("I need to pick up a couple of things from the store:\n\n1. Apples\n2. Bananas\n3. Grapes", "I need to pick up a couple of things from the store:\n\n1. Apples\n2. Bananas\n3. Grapes"),
        ("I need to do three things:\n\n1. Update the prompt\n2. Run the eval\n3. Compare the output", "I need to do three things:\n\n1. Update the prompt\n2. Run the eval\n3. Compare the output"),
        ("I need to bring:\n\n1. Charger\n2. Laptop\n3. Notebook", "I need to bring:\n\n1. Charger\n2. Laptop\n3. Notebook"),
        ("Please check these items:\n\n- Login\n- Keyboard\n- Dictation", "Please check these items:\n\n- Login\n- Keyboard\n- Dictation"),
        ("The launch checklist is:\n\n- screenshots\n- release notes\n- pricing", "The launch checklist is:\n\n- Screenshots\n- Release notes\n- Pricing"),
    ]
    for user, assistant in lists:
        examples.append(Example("structure_preservation", user, assistant))
    examples.extend([
        Example("structure_preservation", "I need to pick up a couple of things from the store. Um:\n\n1. Apples\n2. Bananas\n3. Grapes", "I need to pick up a couple of things from the store:\n\n1. Apples\n2. Bananas\n3. Grapes"),
        Example("structure_preservation", "Please check these items. Hmm:\n\n- Login\n- Keyboard\n- Dictation", "Please check these items:\n\n- Login\n- Keyboard\n- Dictation"),
        Example("structure_preservation", "I need to get a couple things from the store um apples bananas and grapes.", "I need to get a couple of things from the store: apples, bananas, and grapes."),
        Example("structure_preservation", "For tomorrow I need the deck the demo and the screenshots.", "For tomorrow, I need the deck, the demo, and the screenshots."),
    ])
    return examples


def meaning_examples() -> list[Example]:
    seeds = [
        ("This is fucking ridiculous, but I still need you to send it.", "This is fucking ridiculous, but I still need you to send it."),
        ("Why can't you um fucking help me?", "Why can't you fucking help me?"),
        ("I don't get why, um, you're being so rude, but can you like please stop?", "I don't get why you're being so rude, but can you please stop?"),
        ("I don't know why, um, you're making this harder, but can you like please stop?", "I don't know why you're making this harder, but can you please stop?"),
        ("I don't know why, um, you're acting like such a fucking idiot, but can you like please um stop?", "I don't know why you're acting like such a fucking idiot, but can you please stop?"),
        ("That was fucking weird but I think it worked.", "That was fucking weird, but I think it worked."),
        ("I am not trying to be a dick, but this needs to be fixed today.", "I am not trying to be a dick, but this needs to be fixed today."),
        ("I'm frustrated because I already explained this twice.", "I'm frustrated because I already explained this twice."),
        ("I don't want to sound annoying but I need the update today.", "I don't want to sound annoying, but I need the update today."),
        ("I guess we can wait but I really don't want to.", "I guess we can wait, but I really don't want to."),
    ]
    return [Example("meaning_preservation", user, assistant) for user, assistant in seeds]


def grammar_repair_examples() -> list[Example]:
    seeds = [
        ("How you be doing today?", "How are you doing today?"),
        ("What you be working on right now?", "What are you working on right now?"),
        ("You be stupid if you send that version.", "You would be stupid to send that version."),
        ("Sarah and me was going to lunch.", "Sarah and I were going to lunch."),
        ("Sarah and me was going to lunch, but they was running late.", "Sarah and I were going to lunch, but they were running late."),
        ("Me and Jordan was talking about the launch.", "Jordan and I were talking about the launch."),
        ("They was supposed to send the invoice yesterday.", "They were supposed to send the invoice yesterday."),
        ("There was three things left on the checklist.", "There were 3 things left on the checklist."),
        ("He don't know why the app crashed.", "He doesn't know why the app crashed."),
        ("I seen the same bug yesterday.", "I saw the same bug yesterday."),
    ]
    return [Example("grammar_repair", user, assistant) for user, assistant in seeds]


def minimal_examples() -> list[Example]:
    seeds = [
        "I don't know if this is worth it, but I want to try.",
        "Can we move the call to Friday instead of Thursday?",
        "I want this to feel cleaner but still sound like me.",
        "Can you look at the screenshots and tell me which one feels better?",
        "Can you please check this before I send it to Alex?",
        "I need to reschedule because I'm stuck in traffic.",
        "Could you send me the notes from the meeting when you have a minute?",
        "I need to finish the onboarding copy and then test the keyboard.",
        "Please email me at test@example.com when this is ready.",
        "Can you check https://example.com and tell me if the link works?",
    ]
    return [Example("minimal_edit", seed, seed) for seed in seeds]


def code_like_examples() -> list[Example]:
    seeds = [
        ("The variable name is user underscore id and the function is load user.", "The variable name is user_id, and the function is loadUser."),
        ("The endpoint is slash api slash v one slash users.", "The endpoint is /api/v1/users."),
        ("Set is enabled to true and retry count to three.", "Set isEnabled to true and retryCount to 3."),
        ("The file is local rewrite model catalog dot swift.", "The file is LocalRewriteModelCatalog.swift."),
        ("Use command shift p and search for format document.", "Use Command-Shift-P and search for Format Document."),
    ]
    return [Example("code_like_preservation", user, assistant) for user, assistant in seeds]


def medium_edit_examples() -> list[Example]:
    examples = []
    for name in NAMES:
        examples.append(Example("medium_edit", f"Hey {name} can you check the {OBJECTS[1]} when you get a second?", f"Hey {name}, can you check the {OBJECTS[1]} when you get a second?"))
        examples.append(Example("medium_edit", f"Sorry {name} I missed this earlier I was tied up.", f"Sorry {name}, I missed this earlier. I was tied up."))
    for obj in OBJECTS:
        examples.append(Example("medium_edit", f"The {obj} is mostly done but I want to review it one more time.", f"The {obj} is mostly done, but I want to review it one more time."))
        examples.append(Example("medium_edit", f"I think the {obj} needs one more pass before we send it", f"I think the {obj} needs one more pass before we send it."))
    return examples


def live_regression_examples() -> list[Example]:
    seeds = [
        ("Hey, um, are you okay?", "Hey, are you okay?"),
        ("Hey, um what are you doing, um tomorrow?", "Hey, what are you doing tomorrow?"),
        ("Hey, um what are you doing, uh tomorrow?", "Hey, what are you doing tomorrow?"),
        ("Can you, uh, send me that tomorrow?", "Can you send me that tomorrow?"),
        ("Yo, um what are you doing?", "Yo, what are you doing?"),
        ("Um, what's up?", "What's up?"),
        ("I am, like, trying to figure out dinner.", "I am trying to figure out dinner."),
        ("Are you um feeling this vibe? It's like pretty polished. Try it out.", "Are you feeling this vibe? It's pretty polished. Try it out."),
        ("I don't know why, um, you're acting like such a fucking idiot, but can you like please um stop?", "I don't know why you're acting like such a fucking idiot, but can you please stop?"),
        ("Hey, what's going on? Um, are you having any problems?", "Hey, what's going on? Are you having any problems?"),
        ("Hey, um like what are you um doing later if you like I don't know, you know. You know what I mean?", "Hey, what are you doing later? You know what I mean?"),
        ("I bought that for four hundred and ninety nine dollars.", "I bought that for $499."),
        ("Let's meet on May third.", "Let's meet on May 3rd."),
        ("What's up?", "What's up?"),
    ]
    examples = []
    for user, assistant in seeds:
        examples.append(Example("live_regression", user, assistant))
        examples.append(Example("live_regression", f"Quick note: {user[0].lower()}{user[1:]}", f"Quick note: {assistant[0].lower()}{assistant[1:]}"))
        examples.append(Example("live_regression", f"Real quick, {user[0].lower()}{user[1:]}", f"Real quick, {assistant[0].lower()}{assistant[1:]}"))
    return examples


def expanded_live_regression_examples() -> list[Example]:
    seeds = [
        ("Uh can we start?", "Can we start?"),
        ("So like I think we should wait.", "I think we should wait."),
        ("I, I need the report by five.", "I need the report by 5."),
        ("Can you send me the twenty twenty four numbers?", "Can you send me the 2024 numbers?"),
        ("I need to send this to Sarah, um, and then like ask if the client approved the final copy.", "I need to send this to Sarah and ask if the client approved the final copy."),
        ("Hey Alex, um, can you please review the draft when you get a second? I think it is mostly done.", "Hey Alex, can you please review the draft when you get a second? I think it is mostly done."),
        ("Okay, I guess what I'm trying to say is, um, we should not ship this until the onboarding flow feels clear.", "What I'm trying to say is that we should not ship this until the onboarding flow feels clear."),
        ("The address is one two three Main Street, apartment four B, and the zip code is eight five zero zero one.", "The address is 123 Main Street, apartment 4B, and the zip code is 85001."),
        ("I need groceries:\n\n1. Um apples\n2. Like two cartons of eggs\n3. Uh three bags of rice", "I need groceries:\n\n1. Apples\n2. 2 cartons of eggs\n3. 3 bags of rice"),
        ("Here are the launch tasks:\n\n1. Uh finalize screenshots\n2. Submit the build\n3. Like send the announcement email", "Here are the launch tasks:\n\n1. Finalize screenshots\n2. Submit the build\n3. Send the announcement email"),
        ("I don't know, maybe we should, like, keep the first version simple and then add the rest after launch.", "Maybe we should keep the first version simple and add the rest after launch."),
        ("This is kind of annoying because um the button works once and then it like stops responding after the text changes.", "This is annoying because the button works once and then stops responding after the text changes."),
        ("Hey, quick update, um, I finished the first pass on the deck, I fixed the pricing slide, and I still need to clean up the customer quotes.", "Hey, quick update: I finished the first pass on the deck, fixed the pricing slide, and still need to clean up the customer quotes."),
        ("Okay so for the roadmap, um, phase one is onboarding, phase two is billing, and phase three is the admin dashboard.", "For the roadmap, phase 1 is onboarding, phase 2 is billing, and phase 3 is the admin dashboard."),
        ("This is for the release notes. Um we improved dictation cleanup, reduced latency, added better status feedback, and fixed a few edge cases with lists.", "This is for the release notes: we improved dictation cleanup, reduced latency, added better status feedback, and fixed a few edge cases with lists."),
        ("I'm trying to say that, like, the app should feel faster, but we should not sacrifice accuracy just to save two hundred milliseconds.", "I'm trying to say that the app should feel faster, but we should not sacrifice accuracy just to save 200 milliseconds."),
        ("Please summarize this as a note for tomorrow: um call the vendor at nine, confirm the order number four eight seven two, and ask whether delivery can happen before noon.", "Please summarize this as a note for tomorrow: call the vendor at 9, confirm order number 4872, and ask whether delivery can happen before noon."),
        ("I need a clean text to the team that says hey everyone, um, the build is ready, the checklist is done, and we are waiting on final approval from design.", "I need a clean text to the team that says, hey everyone, the build is ready, the checklist is done, and we are waiting on final approval from design."),
        ("Okay, so this is longer. Um I talked to Jamie about the onboarding issue, and she said the main problem is that users do not understand why the keyboard needs full access before they try the first vibe.", "I talked to Jamie about the onboarding issue, and she said the main problem is that users do not understand why the keyboard needs full access before they try the first vibe."),
        ("I want this to sound professional but still direct. Um please tell them we found the issue, we have a fix ready, and we will send another update after QA finishes testing.", "Please tell them we found the issue, have a fix ready, and will send another update after QA finishes testing."),
        ("Hey Maya, um I looked at the schedule and it seems like the best option is to move the workshop from Thursday morning to Friday afternoon so the client can bring the full team.", "Hey Maya, I looked at the schedule, and it seems like the best option is to move the workshop from Thursday morning to Friday afternoon so the client can bring the full team."),
        ("Please turn this into a clean update. Um the first prototype worked, the second prototype was faster, but the third prototype had the best balance between latency and quality.", "Please turn this into a clean update: the first prototype worked, the second prototype was faster, but the third prototype had the best balance between latency and quality."),
        ("I'm dictating a longer product note because I want to make sure the model can handle a real paragraph. Um the user starts by recording a thought, then chooses a vibe, then the app rewrites the text without making them leave the keyboard or guess what happened.", "I'm dictating a longer product note because I want to make sure the model can handle a real paragraph. The user starts by recording a thought, chooses a vibe, and the app rewrites the text without making them leave the keyboard or guess what happened."),
        ("This should become a support reply. Um I understand why that would be frustrating. Please send us the device model, the iOS version, and roughly what time the issue happened so we can check the logs and figure out what went wrong.", "This should become a support reply: I understand why that would be frustrating. Please send us the device model, the iOS version, and roughly what time the issue happened so we can check the logs and figure out what went wrong."),
        ("Here is the longer version for the team. Um we tested the new adapter on short messages, longer notes, grocery lists, status updates, numbers, years, prices, percentages, and messy filler, and the next step is to make sure it behaves consistently on device.", "Here is the longer version for the team: we tested the new adapter on short messages, longer notes, grocery lists, status updates, numbers, years, prices, percentages, and messy filler, and the next step is to make sure it behaves consistently on device."),
        ("I need this as a polished email. Um hi Taylor, thanks for the detailed feedback. I reviewed the notes from Tuesday, updated the timeline, and moved the launch review to April twenty second at eleven thirty so everyone has enough time to prepare.", "Hi Taylor, thanks for the detailed feedback. I reviewed the notes from Tuesday, updated the timeline, and moved the launch review to April 22nd at 11:30 so everyone has enough time to prepare."),
        ("This is a very long dictated thought and it is intentionally messy because I want the test to feel closer to real usage. Um I started by thinking the feature was mostly about speed, but now I think the bigger thing is trust, because people need to know when text is editable, when a vibe is active, and when the original words are back in the field.", "This is a very long dictated thought, and it is intentionally messy because I want the test to feel closer to real usage. I started by thinking the feature was mostly about speed, but now I think the bigger thing is trust, because people need to know when text is editable, when a vibe is active, and when the original words are back in the field."),
        ("I need to capture the weird bug report. Um the user said the first dictation inserted correctly, the second one showed the yellow status label, and then after they edited the text manually the button should have gone back to the normal label color.", "I need to capture the bug report: the user said the first dictation inserted correctly, the second one showed the yellow status label, and after they edited the text manually, the button should have gone back to the normal label color."),
        ("Draft this for the changelog. Um added support for bundled adapters, improved live model validation, expanded polished dictation coverage, and reduced ambiguity around whether the current text can still be reverted.", "Draft this for the changelog: added support for bundled adapters, improved live model validation, expanded polished dictation coverage, and reduced ambiguity around whether the current text can still be reverted."),
    ]
    examples = []
    for user, assistant in seeds:
        examples.append(Example("expanded_live_regression", user, assistant))
        examples.append(Example("expanded_live_regression", f"Quick note: {user[0].lower()}{user[1:]}", f"Quick note: {assistant[0].lower()}{assistant[1:]}"))
        examples.append(Example("expanded_live_regression", f"Please clean this up: {user[0].lower()}{user[1:]}", f"Please clean this up: {assistant[0].lower()}{assistant[1:]}"))
    return examples


def long_form_stress_examples() -> list[Example]:
    return [
        Example(
            "long_form_stress",
            "This is a long message for the product team. Um we tested the keyboard on short notes, long notes, numbered lists, prices, dates, percentages, and rough dictation, but the most important thing is that it preserves the user's meaning while still removing filler.",
            "This is a long message for the product team. We tested the keyboard on short notes, long notes, numbered lists, prices, dates, percentages, and rough dictation, but the most important thing is that it preserves the user's meaning while still removing filler.",
        ),
        Example(
            "long_form_stress",
            "For the weekly update, um, design reviewed the onboarding screen, engineering fixed the adapter loading issue, QA checked twenty seven cases, and support sent over three examples where the model still missed simple filler.",
            "For the weekly update, design reviewed the onboarding screen, engineering fixed the adapter loading issue, QA checked 27 cases, and support sent over 3 examples where the model still missed simple filler.",
        ),
        Example(
            "long_form_stress",
            "I want this note to stay direct but polished. Um the customer paid five thousand twenty two dollars last year, renewed for six thousand one hundred dollars this year, and asked whether the twenty twenty six quote could include one hundred seats.",
            "I want this note to stay direct but polished. The customer paid $5,022 last year, renewed for $6,100 this year, and asked whether the 2026 quote could include 100 seats.",
        ),
        Example(
            "long_form_stress",
            "Can you turn this into something clean for the launch channel? Um we finished the first pass, fixed the top five issues, improved average rewrite latency from one point two seconds to zero point six seconds, and still need one more device test.",
            "Can you turn this into something clean for the launch channel? We finished the first pass, fixed the top 5 issues, improved average rewrite latency from 1.2 seconds to 0.6 seconds, and still need one more device test.",
        ),
    ]


def base_examples() -> list[Example]:
    examples = []
    for factory in [
        live_regression_examples,
        expanded_live_regression_examples,
        numeric_stress_examples,
        long_form_stress_examples,
        short_message_examples,
        rambly_filler_examples,
        long_paragraph_examples,
        filler_examples,
        punctuation_examples,
        number_examples,
        repeat_examples,
        structure_examples,
        structured_number_examples,
        email_note_examples,
        question_request_examples,
        meaning_examples,
        grammar_repair_examples,
        minimal_examples,
        code_like_examples,
        medium_edit_examples,
    ]:
        examples.extend(factory())
    return examples


def expand_examples(seed_examples: list[Example], target: int, split: str) -> list[Example]:
    examples = []
    seen = set()
    prefixes = [
        "",
        "Quick note: ",
        "For context, ",
        "One thing: ",
        "Just checking, ",
        "Real quick, ",
        "Small update: ",
        "Before I forget, ",
        "For tomorrow, ",
        "When you have a second, ",
    ]
    suffix_pairs = [
        ("", ""),
        (" Thanks.", " Thanks."),
        (" Please let me know.", " Please let me know."),
        (" I appreciate it.", " I appreciate it."),
        (" That would help a lot.", " That would help a lot."),
        (" No rush.", " No rush."),
        (" If not, tomorrow is fine.", " If not, tomorrow is fine."),
    ]

    for example in seed_examples:
        add_unique(examples, seen, example)
        if len(examples) >= target:
            return examples[:target]

    index = 0
    while len(examples) < target:
        seed = seed_examples[index % len(seed_examples)]
        prefix = prefixes[(index // len(seed_examples)) % len(prefixes)]
        user_suffix, assistant_suffix = suffix_pairs[(index // (len(seed_examples) * len(prefixes))) % len(suffix_pairs)]
        if prefix:
            user = prefix + seed.user[0].lower() + seed.user[1:] + user_suffix
            assistant = prefix + seed.assistant[0].lower() + seed.assistant[1:] + assistant_suffix
        else:
            user = seed.user + user_suffix
            assistant = seed.assistant + assistant_suffix
        category = seed.category
        add_unique(examples, seen, Example(category, user, assistant))
        index += 1

    return examples


def write_jsonl(path: Path, examples: list[Example]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for example in examples:
            handle.write(json.dumps(record(example), ensure_ascii=False) + "\n")


def main() -> int:
    random.seed(7)
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    seeds = base_examples()
    random.shuffle(seeds)
    pool = expand_examples(seeds, TOTAL_COUNT, "all")
    train = pool[:TRAIN_COUNT]
    valid = pool[TRAIN_COUNT:TRAIN_COUNT + VALID_COUNT]
    test = pool[TRAIN_COUNT + VALID_COUNT:TOTAL_COUNT]

    write_jsonl(DATA_DIR / "train.jsonl", train)
    write_jsonl(DATA_DIR / "valid.jsonl", valid)
    write_jsonl(DATA_DIR / "test.jsonl", test)

    manifest = {
        "model": "Qwen/Qwen2.5-0.5B-Instruct",
        "style": "polished",
        "system_prompt_file": "ModelTraining/prompts/polished/polished_runtime_short.txt",
        "runtime_prompt_file": "ModelTraining/prompts/polished/polished_runtime_short.txt",
        "splits": {
            "train": {"count": len(train), "categories": dict(Counter(example.category for example in train))},
            "valid": {"count": len(valid), "categories": dict(Counter(example.category for example in valid))},
            "test": {"count": len(test), "categories": dict(Counter(example.category for example in test))},
        },
    }
    (REPORT_DIR / "dataset_manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
