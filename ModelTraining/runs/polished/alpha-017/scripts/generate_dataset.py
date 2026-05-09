#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "polished" / "alpha-017-continuation-aint"
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


def build_examples() -> list[Example]:
    examples: list[Example] = []
    seen: set[str] = set()

    aint_pairs = [
        ("I ain't doing that.", "I'm not doing that."),
        ("I ain't be doing that.", "I'm not doing that."),
        ("That ain't nothing.", "That isn't anything."),
        ("She ain't seen the update yet.", "She hasn't seen the update yet."),
        ("Ain't that the same bug from yesterday?", "Isn't that the same bug from yesterday?"),
        ("I ain't going to approve that build.", "I'm not going to approve that build."),
        ("I ain't gonna approve that build.", "I'm not going to approve that build."),
        ("I ain't got time for another broken export.", "I don't have time for another broken export."),
        ("I ain't have the final numbers yet.", "I don't have the final numbers yet."),
        ("We ain't ready to ship this yet.", "We aren't ready to ship this yet."),
        ("We ain't be ready to ship this yet.", "We aren't ready to ship this yet."),
        ("They ain't responding to the invoice.", "They aren't responding to the invoice."),
        ("They ain't sent the signed copy yet.", "They haven't sent the signed copy yet."),
        ("He ain't checked the logs yet.", "He hasn't checked the logs yet."),
        ("It ain't working after the update.", "It isn't working after the update."),
        ("This ain't the version I tested.", "This isn't the version I tested."),
        ("There ain't a reason to delay the review.", "There isn't a reason to delay the review."),
        ("There ain't no reason to delay the review.", "There is no reason to delay the review."),
        ("That ain't the same result we saw yesterday.", "That isn't the same result we saw yesterday."),
        ("Ain't nobody reviewed the contract yet.", "Nobody has reviewed the contract yet."),
        ("Ain't no way the final total is right.", "There is no way the final total is right."),
        ("Ain't it supposed to clean up the filler?", "Isn't it supposed to clean up the filler?"),
        ("Ain't we meeting at three thirty?", "Aren't we meeting at 3:30?"),
        ("You ain't supposed to send that version.", "You aren't supposed to send that version."),
        ("You ain't be supposed to send that version.", "You aren't supposed to send that version."),
        ("The customer ain't replied since Tuesday.", "The customer hasn't replied since Tuesday."),
        ("The adapter ain't loaded on the phone yet.", "The adapter hasn't loaded on the phone yet."),
        ("The button ain't going back to the normal color.", "The button isn't going back to the normal color."),
        ("That list ain't keeping the same structure.", "That list isn't keeping the same structure."),
        ("This output ain't polished enough.", "This output isn't polished enough."),
        ("I ain't saying we should restart.", "I'm not saying we should restart."),
        ("I ain't trying to make this complicated.", "I'm not trying to make this complicated."),
        ("We ain't losing the meaning this time.", "We aren't losing the meaning this time."),
        ("It ain't about speed only.", "It isn't only about speed."),
        ("That ain't what I meant.", "That isn't what I meant."),
    ]
    for user, assistant in aint_pairs:
        add(examples, seen, "bad_grammar_aint", user, assistant)

    aint_context_pairs = [
        (
            "Um I ain't doing that because the build ain't stable yet.",
            "I'm not doing that because the build isn't stable yet.",
        ),
        (
            "Hey, uh, that ain't nothing we should ignore.",
            "Hey, that isn't anything we should ignore.",
        ),
        (
            "I mean she ain't seen the update yet, so we should wait.",
            "She hasn't seen the update yet, so we should wait.",
        ),
        (
            "Okay, so we ain't ready to ship this because the checklist ain't done.",
            "We aren't ready to ship this because the checklist isn't done.",
        ),
        (
            "Like it ain't working after twenty twenty four, and I ain't sure why.",
            "It isn't working after 2024, and I'm not sure why.",
        ),
        (
            "The customer ain't paid the five hundred dollar invoice yet.",
            "The customer hasn't paid the $500 invoice yet.",
        ),
        (
            "I ain't got the order number four eight seven two in front of me.",
            "I don't have order number 4872 in front of me.",
        ),
        (
            "Ain't that the ticket that cost four hundred and ninety nine dollars?",
            "Isn't that the ticket that cost $499?",
        ),
        (
            "This ain't a blocker, but um it should be fixed before June fifth.",
            "This isn't a blocker, but it should be fixed before June 5th.",
        ),
        (
            "I ain't saying the first prototype failed, but the third one ain't ready either.",
            "I'm not saying the first prototype failed, but the third one isn't ready either.",
        ),
        (
            "Here are the things that ain't done:\n\n1. Uh screenshots\n2. Final copy\n3. Like release notes",
            "Here are the things that aren't done:\n\n1. Screenshots\n2. Final copy\n3. Release notes",
        ),
        (
            "This is longer because I ain't sure the model can handle it yet. Um the output needs to keep the same meaning, clean up filler, and avoid changing the numbers from one thousand one hundred four dollars.",
            "This is longer because I'm not sure the model can handle it yet. The output needs to keep the same meaning, clean up filler, and avoid changing the numbers from $1,104.",
        ),
    ]
    for user, assistant in aint_context_pairs:
        add(examples, seen, "bad_grammar_aint_context", user, assistant)

    guard_pairs = [
        ("Hey, um, are you okay?", "Hey, are you okay?"),
        ("What's up?", "What's up?"),
        ("Let's meet on May third.", "Let's meet on May 3rd."),
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
        ("How you be doing today?", "How are you doing today?"),
        ("What you be working on right now?", "What are you working on right now?"),
        ("You be stupid if you send that version.", "You would be stupid to send that version."),
        ("Sarah and me was going to lunch.", "Sarah and I were going to lunch."),
        ("Sarah and me was going to lunch, but they was running late.", "Sarah and I were going to lunch, but they were running late."),
        ("Me and Jordan was talking about the launch.", "Jordan and I were talking about the launch."),
        ("They was supposed to send the invoice yesterday.", "They were supposed to send the invoice yesterday."),
        ("There was three things left on the checklist.", "There were 3 things left on the checklist."),
        ("I seen the same bug yesterday.", "I saw the same bug yesterday."),
        ("Uh can we start?", "Can we start?"),
        ("So like I think we should wait.", "I think we should wait."),
        ("I, I need the report by five.", "I need the report by 5."),
        ("Can you send me the twenty twenty four numbers?", "Can you send me the 2024 numbers?"),
        ("The budget is five thousand twenty two dollars, and the backup estimate is six thousand one hundred.", "The budget is $5,022, and the backup estimate is $6,100."),
        ("Revenue was up twelve point five percent, but churn went down by three percent.", "Revenue was up 12.5%, but churn went down by 3%."),
        ("Let's move the call to three thirty and keep the follow up at four fifteen.", "Let's move the call to 3:30 and keep the follow-up at 4:15."),
        ("Um remind me to order two cases of water, thirty six labels, and one hundred envelopes.", "Remind me to order 2 cases of water, 36 labels, and 100 envelopes."),
        ("I need to send this to Sarah, um, and then like ask if the client approved the final copy.", "I need to send this to Sarah and ask if the client approved the final copy."),
        ("Hey Alex, um, can you please review the draft when you get a second? I think it is mostly done.", "Hey Alex, can you please review the draft when you get a second? I think it is mostly done."),
        ("Okay, I guess what I'm trying to say is, um, we should not ship this until the onboarding flow feels clear.", "What I'm trying to say is that we should not ship this until the onboarding flow feels clear."),
        ("The address is one two three Main Street, apartment four B, and the zip code is eight five zero zero one.", "The address is 123 Main Street, Apartment 4B, and the ZIP code is 85001."),
        ("I need groceries:\n\n1. Um apples\n2. Like two cartons of eggs\n3. Uh three bags of rice", "I need groceries:\n\n1. Apples\n2. 2 cartons of eggs\n3. 3 bags of rice"),
        ("Here are the launch tasks:\n\n1. Uh finalize screenshots\n2. Submit the build\n3. Like send the announcement email", "Here are the launch tasks:\n\n1. Finalize screenshots\n2. Submit the build\n3. Send the announcement email"),
        ("I don't know, maybe we should, like, keep the first version simple and then add the rest after launch.", "Maybe we should keep the first version simple and add the rest after launch."),
        ("This is kind of annoying because um the button works once and then it like stops responding after the text changes.", "This is annoying because the button works once and then stops responding after the text changes."),
        ("I paid thirty two dollars and fifty cents for lunch, nine dollars for parking, and one hundred twenty dollars for the ticket.", "I paid $32.50 for lunch, $9 for parking, and $120 for the ticket."),
        ("The meeting moved from January second to February third, and the deadline is now March fifteenth.", "The meeting moved from January 2nd to February 3rd, and the deadline is now March 15th."),
        ("Can you write this down? Um the first option is fifteen seats, the second option is twenty five seats, and the enterprise plan starts at one hundred seats.", "Can you write this down? The first option is 15 seats, the second option is 25 seats, and the enterprise plan starts at 100 seats."),
        ("Hey, quick update, um, I finished the first pass on the deck, I fixed the pricing slide, and I still need to clean up the customer quotes.", "Hey, quick update: I finished the first pass on the deck, fixed the pricing slide, and still need to clean up the customer quotes."),
        ("Can you tell Jordan that I am running about ten minutes late but I already sent over the notes and the invoice for eight hundred dollars?", "Can you tell Jordan that I am running about 10 minutes late, but I already sent over the notes and the invoice for $800?"),
        ("Okay so for the roadmap, um, phase one is onboarding, phase two is billing, and phase three is the admin dashboard.", "For the roadmap, phase 1 is onboarding, phase 2 is billing, and phase 3 is the admin dashboard."),
        ("I need to explain that the customer paid in twenty twenty three, renewed in twenty twenty four, and wants a quote for twenty twenty five.", "I need to explain that the customer paid in 2023, renewed in 2024, and wants a quote for 2025."),
        ("Uh please draft a message saying I reviewed the contract, everything looks good, and we can move forward once they send the signed copy.", "Please draft a message saying I reviewed the contract, everything looks good, and we can move forward once they send the signed copy."),
        ("This is for the release notes. Um we improved dictation cleanup, reduced latency, added better status feedback, and fixed a few edge cases with lists.", "This is for the release notes: we improved dictation cleanup, reduced latency, added better status feedback, and fixed a few edge cases with lists."),
        ("I'm trying to say that, like, the app should feel faster, but we should not sacrifice accuracy just to save two hundred milliseconds.", "I'm trying to say that the app should feel faster, but we should not sacrifice accuracy just to save 200 milliseconds."),
        ("Please summarize this as a note for tomorrow: um call the vendor at nine, confirm the order number four eight seven two, and ask whether delivery can happen before noon.", "Please summarize this as a note for tomorrow: call the vendor at 9:00, confirm order number 4872, and ask whether delivery can happen before noon."),
        ("I need a clean text to the team that says hey everyone, um, the build is ready, the checklist is done, and we are waiting on final approval from design.", "I need a clean text to the team that says, \"Hey everyone, the build is ready, the checklist is done, and we are waiting on final approval from design.\""),
        ("Okay, so this is longer. Um I talked to Jamie about the onboarding issue, and she said the main problem is that users do not understand why the keyboard needs full access before they try the first vibe.", "I talked to Jamie about the onboarding issue, and she said the main problem is that users do not understand why the keyboard needs full access before they try the first vibe."),
        ("For the invoice, um, the subtotal is one thousand two hundred dollars, the discount is fifteen percent, tax is eighty four dollars, and the final total should be one thousand one hundred four dollars.", "For the invoice, the subtotal is $1,200, the discount is 15%, tax is $84, and the final total should be $1,104."),
        ("I want this to sound professional but still direct. Um please tell them we found the issue, we have a fix ready, and we will send another update after QA finishes testing.", "Please tell them we found the issue, have a fix ready, and will send another update after QA finishes testing."),
        ("Hey Maya, um I looked at the schedule and it seems like the best option is to move the workshop from Thursday morning to Friday afternoon so the client can bring the full team.", "Hey Maya, I looked at the schedule, and it seems like the best option is to move the workshop from Thursday morning to Friday afternoon so the client can bring the full team."),
        ("Please turn this into a clean update. Um the first prototype worked, the second prototype was faster, but the third prototype had the best balance between latency and quality.", "Please turn this into a clean update: the first prototype worked, the second prototype was faster, but the third prototype had the best balance between latency and quality."),
        ("Okay, the customer said they tried the feature three times, um, the first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app.", "The customer said they tried the feature 3 times. The first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app."),
        ("I'm dictating a longer product note because I want to make sure the model can handle a real paragraph. Um the user starts by recording a thought, then chooses a vibe, then the app rewrites the text without making them leave the keyboard or guess what happened.", "I'm dictating a longer product note because I want to make sure the model can handle a real paragraph. The user starts by recording a thought, chooses a vibe, and the app rewrites the text without making them leave the keyboard or guess what happened."),
        ("This should become a support reply. Um I understand why that would be frustrating. Please send us the device model, the iOS version, and roughly what time the issue happened so we can check the logs and figure out what went wrong.", "This should become a support reply: I understand why that would be frustrating. Please send us the device model, the iOS version, and roughly what time the issue happened so we can check the logs and figure out what went wrong."),
        ("Here is the longer version for the team. Um we tested the new adapter on short messages, longer notes, grocery lists, status updates, numbers, years, prices, percentages, and messy filler, and the next step is to make sure it behaves consistently on device.", "Here is the longer version for the team: we tested the new adapter on short messages, longer notes, grocery lists, status updates, numbers, years, prices, percentages, and messy filler, and the next step is to make sure it behaves consistently on device."),
        ("I need this as a polished email. Um hi Taylor, thanks for the detailed feedback. I reviewed the notes from Tuesday, updated the timeline, and moved the launch review to April twenty second at eleven thirty so everyone has enough time to prepare.", "Hi Taylor, thanks for the detailed feedback. I reviewed the notes from Tuesday, updated the timeline, and moved the launch review to April 22nd at 11:30 so everyone has enough time to prepare."),
        ("This is a very long dictated thought and it is intentionally messy because I want the test to feel closer to real usage. Um I started by thinking the feature was mostly about speed, but now I think the bigger thing is trust, because people need to know when text is editable, when a vibe is active, and when the original words are back in the field.", "This is a very long dictated thought, and it is intentionally messy because I want the test to feel closer to real usage. I started by thinking the feature was mostly about speed, but now I think the bigger thing is trust, because people need to know when text is editable, when a vibe is active, and when the original words are back in the field."),
        ("For the internal recap, um, we shipped the first pass on Monday, reviewed twenty seven pieces of feedback on Tuesday, fixed the top five issues on Wednesday, and by Friday the average rewrite time had dropped from one point two seconds to zero point six seconds.", "For the internal recap, we shipped the first pass on Monday, reviewed 27 pieces of feedback on Tuesday, fixed the top 5 issues on Wednesday, and by Friday the average rewrite time had dropped from 1.2 seconds to 0.6 seconds."),
        ("Please clean this up for a client update. Um we are still waiting on the final assets, but engineering finished the integration, QA found two minor issues, and the earliest realistic ship date is June fifth unless the review takes longer than expected.", "Please clean this up for a client update: we are still waiting on the final assets, but engineering finished the integration, QA found 2 minor issues, and the earliest realistic ship date is June 5th unless the review takes longer than expected."),
        ("Turn this into a clean note. Um the warehouse has twelve boxes ready now, another forty eight boxes arriving next week, and a back order of two hundred sixteen units that should arrive in twenty twenty six.", "Turn this into a clean note: the warehouse has 12 boxes ready now, another 48 boxes arriving next week, and a back order of 216 units that should arrive in 2026."),
        ("I need to capture the weird bug report. Um the user said the first dictation inserted correctly, the second one showed the yellow status label, and then after they edited the text manually the button should have gone back to the normal label color.", "I need to capture the bug report: the user said the first dictation inserted correctly, the second one showed the yellow status label, and after they edited the text manually, the button should have gone back to the normal label color."),
        ("Draft this for the changelog. Um added support for bundled adapters, improved live model validation, expanded polished dictation coverage, and reduced ambiguity around whether the current text can still be reverted.", "Draft this for the changelog: added support for bundled adapters, improved live model validation, expanded polished dictation coverage, and reduced ambiguity around whether the current text can still be reverted."),
        ("I bought that for four hundred and ninety nine dollars.", "I bought that for $499."),
    ]
    for user, assistant in guard_pairs:
        add(examples, seen, "live_regression", user, assistant)

    random.Random(17).shuffle(examples)
    return examples


def write_split(path: Path, examples: list[Example]) -> None:
    with path.open("w", encoding="utf-8") as handle:
        for example in examples:
            handle.write(json.dumps(record(example), ensure_ascii=False) + "\n")


def main() -> int:
    examples = build_examples()
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    REPORT_DIR.mkdir(parents=True, exist_ok=True)

    train = examples[:]
    valid = [
        Example("bad_grammar_aint", "I ain't checking that twice.", "I'm not checking that twice."),
        Example("bad_grammar_aint", "That ain't the invoice I sent.", "That isn't the invoice I sent."),
        Example("bad_grammar_aint_context", "Um we ain't changing the deadline from June fifth.", "We aren't changing the deadline from June 5th."),
        Example("live_regression", "The final total should be one thousand one hundred four dollars.", "The final total should be $1,104."),
        Example("live_regression", "Sarah and me was reviewing the plan.", "Sarah and I were reviewing the plan."),
        Example("live_regression", "Here are the follow-up tasks:\n\n1. Uh review screenshots\n2. Submit the notes\n3. Like send the recap email", "Here are the follow-up tasks:\n\n1. Review screenshots\n2. Submit the notes\n3. Send the recap email"),
    ]
    test = [
        Example("bad_grammar_aint", "I ain't sending it yet.", "I'm not sending it yet."),
        Example("bad_grammar_aint", "This ain't ready for review.", "This isn't ready for review."),
        Example("bad_grammar_aint_context", "Ain't that due at four fifteen?", "Isn't that due at 4:15?"),
        Example("live_regression", "The order number is four eight seven two.", "The order number is 4872."),
        Example("live_regression", "How she be doing today?", "How is she doing today?"),
        Example("live_regression", "I bought that for four hundred and eighty nine dollars.", "I bought that for $489."),
    ]

    write_split(DATA_DIR / "train.jsonl", train)
    write_split(DATA_DIR / "valid.jsonl", valid)
    write_split(DATA_DIR / "test.jsonl", test)

    manifest = {
        "version": "polished-alpha-017",
        "purpose": "continuation from alpha-010 for ain't repairs with live-regression guards",
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
