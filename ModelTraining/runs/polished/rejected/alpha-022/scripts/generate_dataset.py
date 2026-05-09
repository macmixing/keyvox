#!/usr/bin/env python3
import json
import random
from collections import Counter
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
MODEL_TRAINING_ROOT = ROOT.parents[2]
DATA_DIR = MODEL_TRAINING_ROOT / "datasets" / "polished" / "rejected" / "alpha-022-continuation-adjacent-numerics"
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
        ("I guess I never really tested this out, but I should try.\n\nWe just really need to observe the results.", "I guess I never really tested this out, but I should try.\n\nWe just really need to observe the results."),
        ("I guess I never really tested to see how this was working.\n\nShould we try something later?", "I guess I never really tested to see how this was working.\n\nShould we try something later?"),
        ("Okay, so I guess we need to test this out for a little bit.\n\nYou know, we really just need to see how paragraphs work.", "I guess we need to test this out for a little bit.\n\nWe really just need to see how paragraphs work."),
        ("Okay, so I think we should test the new adapter for a few minutes.\n\nYou know, the important thing is making sure each paragraph keeps its own meaning.", "I think we should test the new adapter for a few minutes.\n\nThe important thing is making sure each paragraph keeps its own meaning."),
        ("Um I guess the first paragraph should explain what changed today.\n\nYou know, the second paragraph should explain what we still need to verify.", "I guess the first paragraph should explain what changed today.\n\nThe second paragraph should explain what we still need to verify."),
        ("Okay, so the customer asked for a cleaner update before lunch.\n\nYou know, we also need to include the two minor issues QA found.", "The customer asked for a cleaner update before lunch.\n\nWe also need to include the 2 minor issues QA found."),
        ("I guess we should keep watching the latency numbers.\n\nYou know, the paragraph handling is a separate issue from speed.", "I guess we should keep watching the latency numbers.\n\nThe paragraph handling is a separate issue from speed."),
        ("Okay, so I want the first paragraph to stay about testing.\n\nYou know, I want the second paragraph to stay about paragraph structure.", "I want the first paragraph to stay about testing.\n\nI want the second paragraph to stay about paragraph structure."),
        ("The first note is about the release plan.\n\nYou know, the second note is about the support reply we need to send.", "The first note is about the release plan.\n\nThe second note is about the support reply we need to send."),
        ("Okay, so I guess Sarah and me was looking at the logs earlier.\n\nYou know, Jordan found two small issues in the second run.", "I guess Sarah and I were looking at the logs earlier.\n\nJordan found 2 small issues in the second run."),
        ("Um the first paragraph has the setup for the test.\n\nYou know, the second paragraph has the result we need to compare.", "The first paragraph has the setup for the test.\n\nThe second paragraph has the result we need to compare."),
        ("Okay, so the first pass looked better than expected.\n\nYou know, the next pass still needs to preserve the original opening.", "The first pass looked better than expected.\n\nThe next pass still needs to preserve the original opening."),
        ("I guess we can ship this after one more live test.\n\nYou know, we should not call it done if the first paragraph disappears.", "I guess we can ship this after 1 more live test.\n\nWe should not call it done if the first paragraph disappears."),
        ("Okay, so I need to explain why the first paragraph matters.\n\nYou know, it gives context before the second paragraph asks a question.", "I need to explain why the first paragraph matters.\n\nIt gives context before the second paragraph asks a question."),
        ("The first paragraph says the adapter loaded correctly.\n\nYou know, the second paragraph says the rewrite still needs review.", "The first paragraph says the adapter loaded correctly.\n\nThe second paragraph says the rewrite still needs review."),
        ("Okay, so we are checking a paragraph bug right now.\n\nYou know, after that we need to make sure lists and numbers still work.", "We are checking a paragraph bug right now.\n\nAfter that, we need to make sure lists and numbers still work."),
        ("I guess the intro should stay focused on the bug.\n\nYou know, the follow up should stay focused on the fix.", "I guess the intro should stay focused on the bug.\n\nThe follow-up should stay focused on the fix."),
        ("Okay, so the first section is about what happened in the app.\n\nYou know, the second section is about what the model returned.", "The first section is about what happened in the app.\n\nThe second section is about what the model returned."),
        ("Um hey team, I looked at the April twenty second launch notes, and there are like three things we need to clean up. Sarah and me was reviewing the checklist at eleven thirty, and we found two minor issues. I ain't worried about the build, but the screenshots still need a final pass.\n\nOkay, so the customer paid one thousand two hundred dollars in twenty twenty four. They was asking whether the invoice, um, should show the discount as fifteen percent or as one hundred eighty dollars. I seen the same confusion last week, and we should make the update clear.\n\nFor follow up, please confirm the invoice, like send the April twenty second recap, and ask Jordan if the three screenshots are final. We should keep the tone professional but direct. I don't want the meaning to change.", "Hey team, I looked at the April 22nd launch notes, and there are 3 things we need to clean up. Sarah and I were reviewing the checklist at 11:30, and we found 2 minor issues. I'm not worried about the build, but the screenshots still need a final pass.\n\nThe customer paid $1,200 in 2024. They were asking whether the invoice should show the discount as 15% or as $180. I saw the same confusion last week, and we should make the update clear.\n\nFor follow-up, please confirm the invoice, send the April 22nd recap, and ask Jordan if the 3 screenshots are final. We should keep the tone professional but direct. I don't want the meaning to change."),
        ("The client paid one thousand two hundred dollars last year.\n\nThe discount should be one hundred eighty dollars, not eighteen hundred dollars.\n\nPlease include three screenshots in the recap.", "The client paid $1,200 last year.\n\nThe discount should be $180, not $1,800.\n\nPlease include 3 screenshots in the recap."),
        ("Um the invoice total is one thousand two hundred dollars, and the refund is one hundred eighty dollars.\n\nSarah and me was checking the three screenshots at eleven thirty.\n\nI ain't worried about the numbers if the model keeps them precise.", "The invoice total is $1,200, and the refund is $180.\n\nSarah and I were checking the 3 screenshots at 11:30.\n\nI'm not worried about the numbers if the model keeps them precise."),
        ("Please tell Maya the package includes three screenshots, four notes, and two follow ups.\n\nThe customer paid one hundred eighty dollars for setup and one thousand two hundred dollars for the annual plan.\n\nThey was asking for the April twenty second receipt.", "Please tell Maya the package includes 3 screenshots, 4 notes, and 2 follow-ups.\n\nThe customer paid $180 for setup and $1,200 for the annual plan.\n\nThey were asking for the April 22nd receipt."),
        ("Okay, so the first paragraph has one hundred eighty dollars in it.\n\nThe second paragraph has three screenshots and fifteen percent.\n\nThe third paragraph has twenty twenty four and eleven thirty.", "The first paragraph has $180 in it.\n\nThe second paragraph has 3 screenshots and 15%.\n\nThe third paragraph has 2024 and 11:30."),
        ("The invoice should show fifteen percent or one hundred eighty dollars.\n\nDo not change the percentage to eighteen percent.\n\nDo not change the dollar amount to one thousand eight hundred dollars.", "The invoice should show 15% or $180.\n\nDo not change the percentage to 18%.\n\nDo not change the dollar amount to $1,800."),
        ("They asked whether the discount should be fifteen percent or one hundred eighty dollars.\n\nThe first number is a percentage.\n\nThe second number is a dollar amount.", "They asked whether the discount should be 15% or $180.\n\nThe first number is a percentage.\n\nThe second number is a dollar amount."),
        ("Um the customer asked if the discount is fifteen percent or one hundred eighty dollars.\n\nSarah and me was checking the invoice at eleven thirty.\n\nI ain't changing either number.", "The customer asked if the discount is 15% or $180.\n\nSarah and I were checking the invoice at 11:30.\n\nI'm not changing either number."),
        ("The quote includes fifteen percent for the discount and one hundred eighty dollars for setup.\n\nThe total remains one thousand two hundred dollars.\n\nPlease keep those numbers separate.", "The quote includes 15% for the discount and $180 for setup.\n\nThe total remains $1,200.\n\nPlease keep those numbers separate."),
        ("For the client recap, say the discount is fifteen percent, the setup fee is one hundred eighty dollars, and the annual plan is one thousand two hundred dollars.", "For the client recap, say the discount is 15%, the setup fee is $180, and the annual plan is $1,200."),
        ("Okay, so paragraph one says fifteen percent.\n\nParagraph two says one hundred eighty dollars.\n\nParagraph three says one thousand two hundred dollars.", "Paragraph one says 15%.\n\nParagraph two says $180.\n\nParagraph three says $1,200."),
        ("The finance note has three values: fifteen percent, one hundred eighty dollars, and one thousand two hundred dollars.\n\nThe meaning changes if any of those values become each other.\n\nPlease keep each value exact.", "The finance note has 3 values: 15%, $180, and $1,200.\n\nThe meaning changes if any of those values become each other.\n\nPlease keep each value exact."),
        ("Please confirm fifteen percent for the discount.\n\nPlease confirm one hundred eighty dollars for the setup fee.\n\nPlease confirm three screenshots for the recap.", "Please confirm 15% for the discount.\n\nPlease confirm $180 for the setup fee.\n\nPlease confirm 3 screenshots for the recap."),
        ("The quote says one hundred eighty dollars for onboarding.\n\nIt also says one thousand two hundred dollars for the full package.\n\nWe need three screenshots before Friday.", "The quote says $180 for onboarding.\n\nIt also says $1,200 for the full package.\n\nWe need 3 screenshots before Friday."),
        ("Um I saw one hundred eighty dollars in the invoice notes.\n\nLike I also saw three screenshots attached to the April twenty second recap.\n\nSarah and me was going to review it at three thirty.", "I saw $180 in the invoice notes.\n\nI also saw 3 screenshots attached to the April 22nd recap.\n\nSarah and I were going to review it at 3:30."),
        ("I think the first version is ready to test.\n\nWe should still watch the logs after release.", "I think the first version is ready to test.\n\nWe should still watch the logs after release."),
        ("Um I need to send the update today.\n\nThe client is expecting the final version by five.", "I need to send the update today.\n\nThe client is expecting the final version by 5."),
        ("The first pass looks better than I expected.\n\nCan you check the second paragraph before we send it?", "The first pass looks better than I expected.\n\nCan you check the second paragraph before we send it?"),
        ("Okay, the notes are mostly done.\n\nUm please make sure the checklist still includes screenshots and pricing.", "The notes are mostly done.\n\nPlease make sure the checklist still includes screenshots and pricing."),
        ("Here is the quick recap.\n\n1. Um the build is ready\n2. The screenshots are done\n3. Like the release notes need one more pass", "Here is the quick recap.\n\n1. The build is ready\n2. The screenshots are done\n3. The release notes need one more pass"),
        ("I need this to stay as two paragraphs.\n\nThe second paragraph has a different thought that should not be merged.", "I need this to stay as two paragraphs.\n\nThe second paragraph has a different thought that should not be merged."),
        ("We tested the keyboard this morning and the first rewrite worked.\n\nThen we tried a longer note with filler and it still needed cleanup.", "We tested the keyboard this morning, and the first rewrite worked.\n\nThen we tried a longer note with filler, and it still needed cleanup."),
        ("The customer replied after lunch.\n\nShe said the invoice for five hundred dollars looks correct now.", "The customer replied after lunch.\n\nShe said the invoice for $500 looks correct now."),
        ("I want to explain the issue clearly.\n\nIt was not a crash, but the status label made the state confusing.", "I want to explain the issue clearly.\n\nIt was not a crash, but the status label made the state confusing."),
        ("This is probably ready.\n\nShould we run one more live test before we call it done?", "This is probably ready.\n\nShould we run one more live test before we call it done?"),
        ("The first paragraph is about the launch plan.\n\nThe second paragraph is about what we need from design by Friday.", "The first paragraph is about the launch plan.\n\nThe second paragraph is about what we need from design by Friday."),
        ("I talked to Sarah about the bug yesterday.\n\nMe and Jordan was going to review it again today.", "I talked to Sarah about the bug yesterday.\n\nJordan and I were going to review it again today."),
        ("The report says revenue was up twelve percent.\n\nIt also says churn dropped by three point five percent.", "The report says revenue was up 12%.\n\nIt also says churn dropped by 3.5%."),
        ("I ain't worried about the first paragraph.\n\nThe second one ain't preserving the break yet.", "I'm not worried about the first paragraph.\n\nThe second one isn't preserving the break yet."),
        ("Please clean this up for a client update. Um we are still waiting on the final assets, but engineering finished the integration, QA found two minor issues, and the earliest realistic ship date is June fifth unless the review takes longer than expected.", "Please clean this up for a client update: we are still waiting on the final assets, but engineering finished the integration, QA found 2 minor issues, and the earliest realistic ship date is June 5th unless the review takes longer than expected."),
        ("I need groceries:\n\n1. Um apples\n2. Like two cartons of eggs\n3. Uh three bags of rice", "I need groceries:\n\n1. Apples\n2. 2 cartons of eggs\n3. 3 bags of rice"),
        ("Here are the quantities:\n\n1. Um two boxes\n2. Like three labels\n3. Uh four envelopes", "Here are the quantities:\n\n1. 2 boxes\n2. 3 labels\n3. 4 envelopes"),
        ("For QA, we found two minor issues, three visual bugs, and five wording fixes.", "For QA, we found 2 minor issues, 3 visual bugs, and 5 wording fixes."),
        ("The client update has two risks, four open questions, and one blocker.", "The client update has 2 risks, 4 open questions, and 1 blocker."),
        ("We need to order two cases of water.\n\nThe office also needs thirty six labels and one hundred envelopes.", "We need to order 2 cases of water.\n\nThe office also needs 36 labels and 100 envelopes."),
        ("The first paragraph has two examples.\n\nThe second paragraph has three follow-up questions.", "The first paragraph has 2 examples.\n\nThe second paragraph has 3 follow-up questions."),
        ("Please tell them QA found two minor issues.\n\nEngineering already fixed one issue and left one for tomorrow.", "Please tell them QA found 2 minor issues.\n\nEngineering already fixed 1 issue and left 1 for tomorrow."),
        ("The grocery list is below:\n\n1. Two cartons of eggs\n2. Three bags of rice\n3. Four cans of beans", "The grocery list is below:\n\n1. 2 cartons of eggs\n2. 3 bags of rice\n3. 4 cans of beans"),
        ("Um the order includes twenty seven stickers, two boxes, and three backup cables.", "The order includes 27 stickers, 2 boxes, and 3 backup cables."),
        ("The release has two minor issues, but it also has three fixes users have been waiting for.", "The release has 2 minor issues, but it also has 3 fixes users have been waiting for."),
        ("There are two paragraphs here.\n\nThere are three numeric conversions in the second paragraph.", "There are 2 paragraphs here.\n\nThere are 3 numeric conversions in the second paragraph."),
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
        "version": "polished-alpha-022",
        "purpose": "continuation from alpha-021 for preserving adjacent percentage and dollar values",
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
