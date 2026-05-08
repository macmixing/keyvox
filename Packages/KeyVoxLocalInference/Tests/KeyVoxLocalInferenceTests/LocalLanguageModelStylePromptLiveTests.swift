import KeyVoxStyleRewrite
import XCTest
@testable import KeyVoxLocalInference

final class LocalLanguageModelStylePromptLiveTests: XCTestCase {
    @MainActor
    func testLiveLFMExactStylePromptsWhenEnabled() async throws {
        guard ProcessInfo.processInfo.environment["KEYVOX_RUN_LOCAL_LFM_STYLE_TESTS"] == "1" else {
            throw XCTSkip("Set KEYVOX_RUN_LOCAL_LFM_STYLE_TESTS=1 to run live local style prompt tests.")
        }
        guard let modelPath = ProcessInfo.processInfo.environment["KEYVOX_LOCAL_LFM_MODEL_PATH"] else {
            throw XCTSkip("Set KEYVOX_LOCAL_LFM_MODEL_PATH to a local GGUF file.")
        }

        let modelURL = URL(fileURLWithPath: modelPath)
        let adapterURL = ProcessInfo.processInfo.environment["KEYVOX_LOCAL_LFM_ADAPTER_PATH"]
            .map { URL(fileURLWithPath: $0) }
        let adapterScale = ProcessInfo.processInfo.environment["KEYVOX_LOCAL_LFM_ADAPTER_SCALE"]
            .flatMap(Float.init) ?? 1.0
        let responder = LiveLocalStyleResponder(
            modelURL: modelURL,
            adapterURL: adapterURL,
            adapterScale: adapterScale
        )
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: ApproximateTextTransformTokenCounter(),
            chunkResponderProvider: { _ in responder }
        )
        var failures: [String] = []
        let styleFilter = ProcessInfo.processInfo.environment["KEYVOX_LIVE_STYLE_FILTER"]

        for testCase in Self.cases {
            if let styleFilter, testCase.style.rawValue != styleFilter {
                continue
            }
            let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
                for: testCase.style,
                baseText: testCase.input
            ))
            let result = await transformer.transform(request)
            let expectedApplied = testCase.expected != testCase.input
            if let requirements = Self.polishedCoverageRequirements[testCase.input] {
                let missingFragments = requirements.requiredFragments.filter { !result.finalText.contains($0) }
                let presentForbiddenFragments = requirements.forbiddenFragments.filter {
                    result.finalText.localizedCaseInsensitiveContains($0)
                }
                let paragraphCount = result.finalText
                    .components(separatedBy: "\n\n")
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .count
                let missedParagraphCount = requirements.minimumParagraphCount.map { paragraphCount < $0 } ?? false
                if !missingFragments.isEmpty || !presentForbiddenFragments.isEmpty || missedParagraphCount || result.applied != expectedApplied {
                    failures.append(
                        "\(testCase.style.rawValue): \(testCase.input) => \(result.finalText); missing=\(missingFragments); forbidden=\(presentForbiddenFragments); paragraphs=\(paragraphCount); applied=\(result.applied)"
                    )
                }
                continue
            }

            if result.finalText != testCase.expected || result.applied != expectedApplied {
                failures.append(
                    "\(testCase.style.rawValue): \(testCase.input) => \(result.finalText); expected=\(testCase.expected); applied=\(result.applied)"
                )
            }
        }

        await responder.unload()

        XCTAssertTrue(
            failures.isEmpty,
            "Production local style prompts produced unexpected outputs.\n\n\(failures.joined(separator: "\n"))"
        )
    }

    private static let polishedThreeParagraphGauntletInput = "Um hey team, I looked at the April 22nd launch notes, and there are like 3 things we need to clean up. Sarah and me was reviewing the checklist at 11:30, and we found 2 minor issues. I ain't worried about the build, but the screenshots still need a final pass.\n\nOkay, so the customer paid $1,200 in twenty twenty four. They was asking whether the invoice, um, should show the discount as 15% or as $180. I seen the same confusion last week, and we should make the update clear.\n\nFor follow up, please confirm the invoice, like send the April 22nd recap, and ask Jordan if the 3 screenshots are final. We should keep the tone professional but direct. I don't want the meaning to change."

    private static let polishedFourParagraphGauntletInput = "Okay, so I guess the first thing is that the onboarding copy still feels confusing. Um users be asking why the keyboard needs full access, and that question is fair. We should explain it in 2 sentences, not 5.\n\nThe second thing is performance. Like the rewrite took 0.6 seconds on my phone, but 1 test took 1.2 seconds after the model woke up. I ain't calling that a blocker, but we should keep watching it.\n\nThird, Sarah and me was checking paragraph behavior again. The model duplicated the second paragraph once, and it dropped the first idea. That ain't acceptable because every paragraph needs to keep its own meaning.\n\nFinally, please send Maya a clean update by 3:30 tomorrow. Tell her we tested 4 longer notes, fixed 2 failures, and kept the current adapter bundled in the app. If anything changes, we can run another live test before June 5th."

    private static let cases = [
        LiveStylePromptCase(
            style: .casual,
            input: "Hey, um, are you okay?",
            expected: "Hey, are you okay?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Hey, um, are you okay?",
            expected: "Hey, are you okay?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Hey, um, are you okay?",
            expected: "hey are you okay?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "What's up?",
            expected: "What's up?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "What's up?",
            expected: "What's up?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "What's up?",
            expected: "whats up?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Let's meet on May third.",
            expected: "Let's meet on May 3rd."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Let's meet on May third.",
            expected: "Let's meet on May 3rd."
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Let's meet on May third.",
            expected: "lets meet on may 3rd"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "I need to pick up a couple of things from the store:\n\n1. Um apples\n2. Bananas\n3. Uh grapes",
            expected: "I need to pick up a couple of things from the store:\n\n1. Apples\n2. Bananas\n3. Grapes"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "I need to pick up a couple of things from the store:\n\n1. Um apples\n2. Bananas\n3. Uh grapes",
            expected: "i need to pick up a couple of things from the store\n\n1. apples\n2. bananas\n3. grapes"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Hey, um what are you doing, um tomorrow?",
            expected: "Hey, what are you doing tomorrow?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Hey, um what are you doing, um tomorrow?",
            expected: "Hey, what are you doing tomorrow?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Hey, um what are you doing, um tomorrow?",
            expected: "hey what are you doing tomorrow?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Hey, um what are you doing, uh tomorrow?",
            expected: "Hey, what are you doing tomorrow?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Hey, um what are you doing, uh tomorrow?",
            expected: "Hey, what are you doing tomorrow?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Hey, um what are you doing, uh tomorrow?",
            expected: "hey what are you doing tomorrow?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Phase three. Yo, uh what are you doing tomorrow?",
            expected: "Phase three. Yo, what are you doing tomorrow?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Phase three. Yo, uh what are you doing tomorrow?",
            expected: "phase three. yo what are you doing tomorrow?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Can you, uh, send me that tomorrow?",
            expected: "Can you send me that tomorrow?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Can you, uh, send me that tomorrow?",
            expected: "Can you send me that tomorrow?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Can you, uh, send me that tomorrow?",
            expected: "can you send me that tomorrow?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Yo, um what are you doing?",
            expected: "Yo, what are you doing?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Yo, um what are you doing?",
            expected: "Yo, what are you doing?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Yo, um what are you doing?",
            expected: "yo what are you doing?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Um, what's up?",
            expected: "What's up?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Um, what's up?",
            expected: "What's up?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Um, what's up?",
            expected: "whats up?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "I am, like, trying to figure out dinner.",
            expected: "I am trying to figure out dinner."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I am, like, trying to figure out dinner.",
            expected: "I am trying to figure out dinner."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Are you um feeling this vibe? It's like pretty polished. Try it out.",
            expected: "Are you feeling this vibe? It's pretty polished. Try it out."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I don't know why, um, you're acting like such a fucking idiot, but can you like please um stop?",
            expected: "I don't know why you're acting like such a fucking idiot, but can you please stop?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Hey, what's going on? Um, are you having any problems?",
            expected: "Hey, what's going on? Are you having any problems?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Hey, um like what are you um doing later if you like I don't know, you know. You know what I mean?",
            expected: "Hey, what are you doing later? You know what I mean?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "How you be doing today?",
            expected: "How are you doing today?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "What you be working on right now?",
            expected: "What are you working on right now?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "You be stupid if you send that version.",
            expected: "You would be stupid to send that version."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Sarah and me was going to lunch.",
            expected: "Sarah and I were going to lunch."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Sarah and me was going to lunch, but they was running late.",
            expected: "Sarah and I were going to lunch, but they were running late."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Me and Jordan was talking about the launch.",
            expected: "Jordan and I were talking about the launch."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "They was supposed to send the invoice yesterday.",
            expected: "They were supposed to send the invoice yesterday."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "There was three things left on the checklist.",
            expected: "There were 3 things left on the checklist."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I seen the same bug yesterday.",
            expected: "I saw the same bug yesterday."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I ain't doing that.",
            expected: "I'm not doing that."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I ain't be doing that.",
            expected: "I'm not doing that."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "That ain't nothing.",
            expected: "That isn't anything."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "She ain't seen the update yet.",
            expected: "She hasn't seen the update yet."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Ain't that the same bug from yesterday?",
            expected: "Isn't that the same bug from yesterday?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Uh can we start?",
            expected: "Can we start?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "So like I think we should wait.",
            expected: "I think we should wait."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I, I need the report by five.",
            expected: "I need the report by 5."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Can you send me the twenty twenty four numbers?",
            expected: "Can you send me the 2024 numbers?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "The budget is five thousand twenty two dollars, and the backup estimate is six thousand one hundred.",
            expected: "The budget is $5,022, and the backup estimate is $6,100."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Revenue was up twelve point five percent, but churn went down by three percent.",
            expected: "Revenue was up 12.5%, but churn went down by 3%."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Let's move the call to three thirty and keep the follow up at four fifteen.",
            expected: "Let's move the call to 3:30 and keep the follow-up at 4:15."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Um remind me to order two cases of water, thirty six labels, and one hundred envelopes.",
            expected: "Remind me to order 2 cases of water, 36 labels, and 100 envelopes."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I need to send this to Sarah, um, and then like ask if the client approved the final copy.",
            expected: "I need to send this to Sarah and ask if the client approved the final copy."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Hey Alex, um, can you please review the draft when you get a second? I think it is mostly done.",
            expected: "Hey Alex, can you please review the draft when you get a second? I think it is mostly done."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Okay, I guess what I'm trying to say is, um, we should not ship this until the onboarding flow feels clear.",
            expected: "What I'm trying to say is that we should not ship this until the onboarding flow feels clear."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "The address is one two three Main Street, apartment four B, and the zip code is eight five zero zero one.",
            expected: "The address is 123 Main Street, Apartment 4B, and the ZIP code is 85001."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I need groceries:\n\n1. Um apples\n2. Like two cartons of eggs\n3. Uh three bags of rice",
            expected: "I need groceries:\n\n1. Apples\n2. 2 cartons of eggs\n3. 3 bags of rice"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Here are the launch tasks:\n\n1. Uh finalize screenshots\n2. Submit the build\n3. Like send the announcement email",
            expected: "Here are the launch tasks:\n\n1. Finalize screenshots\n2. Submit the build\n3. Send the announcement email"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I guess I never really tested this out, but I should try.\n\nWe just really need to observe the results.",
            expected: "I guess I never really tested this out, but I should try.\n\nWe just really need to observe the results."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I guess I never really tested to see how this was working.\n\nShould we try something later?",
            expected: "I guess I never really tested to see how this was working.\n\nShould we try something later?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Okay, so I guess we need to test this out for a little bit.\n\nYou know, we really just need to see how paragraphs work.",
            expected: "I guess we need to test this out for a little bit.\n\nWe really just need to see how paragraphs work."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: polishedThreeParagraphGauntletInput,
            expected: "Hey team, I looked at the April 22nd launch notes, and there are 3 things we need to clean up. Sarah and I were reviewing the checklist at 11:30, and we found 2 minor issues. I'm not worried about the build, but the screenshots still need a final pass.\n\nThe customer paid $1,200 in 2024. They were asking whether the invoice should show the discount as 15% or as $180. I saw the same confusion last week, and we should make the update clear.\n\nFor follow-up, please confirm the invoice, send the April 22nd recap, and ask Jordan if the 3 screenshots are final. We should keep the tone professional but direct. I don't want the meaning to change."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: polishedFourParagraphGauntletInput,
            expected: "The first thing is that the onboarding copy still feels confusing. Users are asking why the keyboard needs full access, and that question is fair. We should explain it in 2 sentences, not 5.\n\nThe second thing is performance. The rewrite took 0.6 seconds on my phone, but 1 test took 1.2 seconds after the model woke up. I'm not calling that a blocker, but we should keep watching it.\n\nThird, Sarah and I were checking paragraph behavior again. The model duplicated the second paragraph once, and it dropped the first idea. That isn't acceptable because every paragraph needs to keep its own meaning.\n\nFinally, please send Maya a clean update by 3:30 tomorrow. Tell her we tested 4 longer notes, fixed 2 failures, and kept the current adapter bundled in the app. If anything changes, we can run another live test before June 5th."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I don't know, maybe we should, like, keep the first version simple and then add the rest after launch.",
            expected: "Maybe we should keep the first version simple and add the rest after launch."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "This is kind of annoying because um the button works once and then it like stops responding after the text changes.",
            expected: "This is annoying because the button works once and then stops responding after the text changes."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I paid thirty two dollars and fifty cents for lunch, nine dollars for parking, and one hundred twenty dollars for the ticket.",
            expected: "I paid $32.50 for lunch, $9 for parking, and $120 for the ticket."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "The meeting moved from January second to February third, and the deadline is now March fifteenth.",
            expected: "The meeting moved from January 2nd to February 3rd, and the deadline is now March 15th."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Can you write this down? Um the first option is fifteen seats, the second option is twenty five seats, and the enterprise plan starts at one hundred seats.",
            expected: "Can you write this down? The first option is 15 seats, the second option is 25 seats, and the enterprise plan starts at 100 seats."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Hey, quick update, um, I finished the first pass on the deck, I fixed the pricing slide, and I still need to clean up the customer quotes.",
            expected: "Hey, quick update: I finished the first pass on the deck, fixed the pricing slide, and still need to clean up the customer quotes."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Can you tell Jordan that I am running about ten minutes late but I already sent over the notes and the invoice for eight hundred dollars?",
            expected: "Can you tell Jordan that I am running about 10 minutes late, but I already sent over the notes and the invoice for $800?"
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Okay so for the roadmap, um, phase one is onboarding, phase two is billing, and phase three is the admin dashboard.",
            expected: "For the roadmap, phase 1 is onboarding, phase 2 is billing, and phase 3 is the admin dashboard."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I need to explain that the customer paid in twenty twenty three, renewed in twenty twenty four, and wants a quote for twenty twenty five.",
            expected: "I need to explain that the customer paid in 2023, renewed in 2024, and wants a quote for 2025."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Uh please draft a message saying I reviewed the contract, everything looks good, and we can move forward once they send the signed copy.",
            expected: "Please draft a message saying I reviewed the contract, everything looks good, and we can move forward once they send the signed copy."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "This is for the release notes. Um we improved dictation cleanup, reduced latency, added better status feedback, and fixed a few edge cases with lists.",
            expected: "This is for the release notes: we improved dictation cleanup, reduced latency, added better status feedback, and fixed a few edge cases with lists."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I'm trying to say that, like, the app should feel faster, but we should not sacrifice accuracy just to save two hundred milliseconds.",
            expected: "I'm trying to say that the app should feel faster, but we should not sacrifice accuracy just to save 200 milliseconds."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Please summarize this as a note for tomorrow: um call the vendor at nine, confirm the order number four eight seven two, and ask whether delivery can happen before noon.",
            expected: "Please summarize this as a note for tomorrow: call the vendor at 9:00, confirm order number 4872, and ask whether delivery can happen before noon."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I need a clean text to the team that says hey everyone, um, the build is ready, the checklist is done, and we are waiting on final approval from design.",
            expected: "I need a clean text to the team that says, \"Hey everyone, the build is ready, the checklist is done, and we are waiting on final approval from design.\""
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Okay, so this is longer. Um I talked to Jamie about the onboarding issue, and she said the main problem is that users do not understand why the keyboard needs full access before they try the first vibe.",
            expected: "I talked to Jamie about the onboarding issue, and she said the main problem is that users do not understand why the keyboard needs full access before they try the first vibe."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "For the invoice, um, the subtotal is one thousand two hundred dollars, the discount is fifteen percent, tax is eighty four dollars, and the final total should be one thousand one hundred four dollars.",
            expected: "For the invoice, the subtotal is $1,200, the discount is 15%, tax is $84, and the final total should be $1,104."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I want this to sound professional but still direct. Um please tell them we found the issue, we have a fix ready, and we will send another update after QA finishes testing.",
            expected: "Please tell them we found the issue, have a fix ready, and will send another update after QA finishes testing."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Hey Maya, um I looked at the schedule and it seems like the best option is to move the workshop from Thursday morning to Friday afternoon so the client can bring the full team.",
            expected: "Hey Maya, I looked at the schedule, and it seems like the best option is to move the workshop from Thursday morning to Friday afternoon so the client can bring the full team."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Please turn this into a clean update. Um the first prototype worked, the second prototype was faster, but the third prototype had the best balance between latency and quality.",
            expected: "Please turn this into a clean update: the first prototype worked, the second prototype was faster, but the third prototype had the best balance between latency and quality."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Okay, the customer said they tried the feature three times, um, the first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app.",
            expected: "The customer said they tried the feature 3 times. The first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I'm dictating a longer product note because I want to make sure the model can handle a real paragraph. Um the user starts by recording a thought, then chooses a vibe, then the app rewrites the text without making them leave the keyboard or guess what happened.",
            expected: "I'm dictating a longer product note because I want to make sure the model can handle a real paragraph. The user starts by recording a thought, chooses a vibe, and the app rewrites the text without making them leave the keyboard or guess what happened."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "This should become a support reply. Um I understand why that would be frustrating. Please send us the device model, the iOS version, and roughly what time the issue happened so we can check the logs and figure out what went wrong.",
            expected: "This should become a support reply: I understand why that would be frustrating. Please send us the device model, the iOS version, and roughly what time the issue happened so we can check the logs and figure out what went wrong."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Here is the longer version for the team. Um we tested the new adapter on short messages, longer notes, grocery lists, status updates, numbers, years, prices, percentages, and messy filler, and the next step is to make sure it behaves consistently on device.",
            expected: "Here is the longer version for the team: we tested the new adapter on short messages, longer notes, grocery lists, status updates, numbers, years, prices, percentages, and messy filler, and the next step is to make sure it behaves consistently on device."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I need this as a polished email. Um hi Taylor, thanks for the detailed feedback. I reviewed the notes from Tuesday, updated the timeline, and moved the launch review to April twenty second at eleven thirty so everyone has enough time to prepare.",
            expected: "Hi Taylor, thanks for the detailed feedback. I reviewed the notes from Tuesday, updated the timeline, and moved the launch review to April 22nd at 11:30 so everyone has enough time to prepare."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "This is a very long dictated thought and it is intentionally messy because I want the test to feel closer to real usage. Um I started by thinking the feature was mostly about speed, but now I think the bigger thing is trust, because people need to know when text is editable, when a vibe is active, and when the original words are back in the field.",
            expected: "This is a very long dictated thought, and it is intentionally messy because I want the test to feel closer to real usage. I started by thinking the feature was mostly about speed, but now I think the bigger thing is trust, because people need to know when text is editable, when a vibe is active, and when the original words are back in the field."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "For the internal recap, um, we shipped the first pass on Monday, reviewed twenty seven pieces of feedback on Tuesday, fixed the top five issues on Wednesday, and by Friday the average rewrite time had dropped from one point two seconds to zero point six seconds.",
            expected: "For the internal recap, we shipped the first pass on Monday, reviewed 27 pieces of feedback on Tuesday, fixed the top 5 issues on Wednesday, and by Friday the average rewrite time had dropped from 1.2 seconds to 0.6 seconds."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Please clean this up for a client update. Um we are still waiting on the final assets, but engineering finished the integration, QA found two minor issues, and the earliest realistic ship date is June fifth unless the review takes longer than expected.",
            expected: "Please clean this up for a client update: we are still waiting on the final assets, but engineering finished the integration, QA found 2 minor issues, and the earliest realistic ship date is June 5th unless the review takes longer than expected."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Turn this into a clean note. Um the warehouse has twelve boxes ready now, another forty eight boxes arriving next week, and a back order of two hundred sixteen units that should arrive in twenty twenty six.",
            expected: "Turn this into a clean note: the warehouse has 12 boxes ready now, another 48 boxes arriving next week, and a back order of 216 units that should arrive in 2026."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I need to capture the weird bug report. Um the user said the first dictation inserted correctly, the second one showed the yellow status label, and then after they edited the text manually the button should have gone back to the normal label color.",
            expected: "I need to capture the bug report: the user said the first dictation inserted correctly, the second one showed the yellow status label, and after they edited the text manually, the button should have gone back to the normal label color."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "Draft this for the changelog. Um added support for bundled adapters, improved live model validation, expanded polished dictation coverage, and reduced ambiguity around whether the current text can still be reverted.",
            expected: "Draft this for the changelog: added support for bundled adapters, improved live model validation, expanded polished dictation coverage, and reduced ambiguity around whether the current text can still be reverted."
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "I am, like, trying to figure out dinner.",
            expected: "i am trying to figure out dinner"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Why can't you fucking help me?",
            expected: "Why can't you fucking help me?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Why can't you um fucking help me?",
            expected: "Why can't you fucking help me?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Why can't you fucking help me?",
            expected: "why cant you fucking help me?"
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Why can't you um fucking help me?",
            expected: "why cant you fucking help me?"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "I'm just having a working awesome day.",
            expected: "I'm just having a working awesome day."
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "I'm just having a working awesome day.",
            expected: "im just having a working awesome day"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "I bought that for four hundred and ninety nine dollars.",
            expected: "I bought that for $499."
        ),
        LiveStylePromptCase(
            style: .polished,
            input: "I bought that for four hundred and ninety nine dollars.",
            expected: "I bought that for $499."
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "I bought that for four hundred and ninety nine dollars.",
            expected: "i bought that for $499"
        ),
        LiveStylePromptCase(
            style: .casual,
            input: "Me and Sarah was talking about the launch.",
            expected: "Me and Sarah was talking about the launch."
        ),
        LiveStylePromptCase(
            style: .chill,
            input: "Me and Sarah was talking about the launch.",
            expected: "me and sarah was talking about the launch"
        ),
    ]

    private static let polishedCoverageRequirements: [String: LiveStylePromptRequirements] = [
        "Uh can we start?": LiveStylePromptRequirements(
            requiredFragments: ["Can we start?"]
        ),
        "So like I think we should wait.": LiveStylePromptRequirements(
            requiredFragments: ["I think we should wait."],
            extraForbiddenFragments: [" like "]
        ),
        "I, I need the report by five.": LiveStylePromptRequirements(
            requiredFragments: ["report", "5"],
            extraForbiddenFragments: ["I, I"]
        ),
        "Can you send me the twenty twenty four numbers?": LiveStylePromptRequirements(
            requiredFragments: ["2024"]
        ),
        "The budget is five thousand twenty two dollars, and the backup estimate is six thousand one hundred.": LiveStylePromptRequirements(
            requiredFragments: ["$5,022", "$6,100"]
        ),
        "Revenue was up twelve point five percent, but churn went down by three percent.": LiveStylePromptRequirements(
            requiredFragments: ["12.5%", "3%"]
        ),
        "Let's move the call to three thirty and keep the follow up at four fifteen.": LiveStylePromptRequirements(
            requiredFragments: ["3:30", "4:15"]
        ),
        "Um remind me to order two cases of water, thirty six labels, and one hundred envelopes.": LiveStylePromptRequirements(
            requiredFragments: ["2 cases", "36 labels", "100 envelopes"]
        ),
        "I need to send this to Sarah, um, and then like ask if the client approved the final copy.": LiveStylePromptRequirements(
            requiredFragments: ["Sarah", "client approved the final copy"],
            extraForbiddenFragments: [" like "]
        ),
        "Hey Alex, um, can you please review the draft when you get a second? I think it is mostly done.": LiveStylePromptRequirements(
            requiredFragments: ["Hey Alex", "review the draft", "mostly done"]
        ),
        "Okay, I guess what I'm trying to say is, um, we should not ship this until the onboarding flow feels clear.": LiveStylePromptRequirements(
            requiredFragments: ["ship this", "onboarding flow feels clear"]
        ),
        "The address is one two three Main Street, apartment four B, and the zip code is eight five zero zero one.": LiveStylePromptRequirements(
            requiredFragments: ["123 Main Street", "4B", "85001"]
        ),
        "I need groceries:\n\n1. Um apples\n2. Like two cartons of eggs\n3. Uh three bags of rice": LiveStylePromptRequirements(
            requiredFragments: ["1. Apples", "2 cartons", "3 bags"],
            extraForbiddenFragments: ["Like"]
        ),
        "Here are the launch tasks:\n\n1. Uh finalize screenshots\n2. Submit the build\n3. Like send the announcement email": LiveStylePromptRequirements(
            requiredFragments: ["1. Finalize screenshots", "2. Submit the build", "3. Send the announcement email"]
        ),
        polishedThreeParagraphGauntletInput: LiveStylePromptRequirements(
            requiredFragments: [
                "April 22nd",
                "3 things",
                "Sarah and I were reviewing",
                "11:30",
                "2 minor issues",
                "I'm not worried",
                "The customer paid $1,200 in 2024",
                "15%",
                "$180",
                "I saw the same confusion",
                "confirm the invoice",
                "April 22nd recap",
                "screenshots are final",
                "I don't want the meaning to change",
            ],
            extraForbiddenFragments: [
                " um",
                " like ",
                "Sarah and me",
                "They was",
                "I seen",
                "ain't",
                "twenty twenty four",
            ],
            minimumParagraphCount: 3
        ),
        polishedFourParagraphGauntletInput: LiveStylePromptRequirements(
            requiredFragments: [
                "onboarding copy",
                "Users are asking",
                "2 sentences",
                "not 5",
                "0.6 seconds",
                "1.2 seconds",
                "I'm not calling",
                "Sarah and I were checking",
                "duplicated the second paragraph",
                "dropped the first idea",
                "That isn't acceptable",
                "3:30",
                "4 longer notes",
                "2 failures",
                "June 5th",
            ],
            extraForbiddenFragments: [
                " um",
                " like ",
                "users be asking",
                "Sarah and me",
                "ain't",
                "zero point six",
                "one point two",
            ],
            minimumParagraphCount: 4
        ),
        "I don't know, maybe we should, like, keep the first version simple and then add the rest after launch.": LiveStylePromptRequirements(
            requiredFragments: ["keep the first version simple", "add the rest after launch"],
            extraForbiddenFragments: [" like "]
        ),
        "This is kind of annoying because um the button works once and then it like stops responding after the text changes.": LiveStylePromptRequirements(
            requiredFragments: ["button works once", "stops responding after the text changes"],
            extraForbiddenFragments: ["kind of", " like "]
        ),
        "I paid thirty two dollars and fifty cents for lunch, nine dollars for parking, and one hundred twenty dollars for the ticket.": LiveStylePromptRequirements(
            requiredFragments: ["$32.50", "$9", "$120"]
        ),
        "The meeting moved from January second to February third, and the deadline is now March fifteenth.": LiveStylePromptRequirements(
            requiredFragments: ["January 2nd", "February 3rd", "March 15th"]
        ),
        "Can you write this down? Um the first option is fifteen seats, the second option is twenty five seats, and the enterprise plan starts at one hundred seats.": LiveStylePromptRequirements(
            requiredFragments: ["15 seats", "25 seats", "100 seats"]
        ),
        "Hey, quick update, um, I finished the first pass on the deck, I fixed the pricing slide, and I still need to clean up the customer quotes.": LiveStylePromptRequirements(
            requiredFragments: ["finished the first pass", "pricing slide", "customer quotes"]
        ),
        "Can you tell Jordan that I am running about ten minutes late but I already sent over the notes and the invoice for eight hundred dollars?": LiveStylePromptRequirements(
            requiredFragments: ["Jordan", "10 minutes late", "$800"]
        ),
        "Okay so for the roadmap, um, phase one is onboarding, phase two is billing, and phase three is the admin dashboard.": LiveStylePromptRequirements(
            requiredFragments: ["phase 1", "phase 2", "phase 3"]
        ),
        "I need to explain that the customer paid in twenty twenty three, renewed in twenty twenty four, and wants a quote for twenty twenty five.": LiveStylePromptRequirements(
            requiredFragments: ["2023", "2024", "2025"]
        ),
        "Uh please draft a message saying I reviewed the contract, everything looks good, and we can move forward once they send the signed copy.": LiveStylePromptRequirements(
            requiredFragments: ["reviewed the contract", "move forward", "signed copy"]
        ),
        "This is for the release notes. Um we improved dictation cleanup, reduced latency, added better status feedback, and fixed a few edge cases with lists.": LiveStylePromptRequirements(
            requiredFragments: ["dictation cleanup", "reduced latency", "status feedback", "lists"]
        ),
        "I'm trying to say that, like, the app should feel faster, but we should not sacrifice accuracy just to save two hundred milliseconds.": LiveStylePromptRequirements(
            requiredFragments: ["feel faster", "accuracy", "200 milliseconds"],
            extraForbiddenFragments: [" like "]
        ),
        "Please summarize this as a note for tomorrow: um call the vendor at nine, confirm the order number four eight seven two, and ask whether delivery can happen before noon.": LiveStylePromptRequirements(
            requiredFragments: ["call the vendor", "9", "4872", "before noon"]
        ),
        "I need a clean text to the team that says hey everyone, um, the build is ready, the checklist is done, and we are waiting on final approval from design.": LiveStylePromptRequirements(
            requiredFragments: ["team", "build is ready", "checklist is done", "final approval"]
        ),
        "Okay, so this is longer. Um I talked to Jamie about the onboarding issue, and she said the main problem is that users do not understand why the keyboard needs full access before they try the first vibe.": LiveStylePromptRequirements(
            requiredFragments: ["Jamie", "onboarding issue", "full access", "first vibe"]
        ),
        "For the invoice, um, the subtotal is one thousand two hundred dollars, the discount is fifteen percent, tax is eighty four dollars, and the final total should be one thousand one hundred four dollars.": LiveStylePromptRequirements(
            requiredFragments: ["$1,200", "15%", "$84", "$1,104"]
        ),
        "I want this to sound professional but still direct. Um please tell them we found the issue, we have a fix ready, and we will send another update after QA finishes testing.": LiveStylePromptRequirements(
            requiredFragments: ["found the issue", "fix ready", "QA finishes testing"]
        ),
        "Hey Maya, um I looked at the schedule and it seems like the best option is to move the workshop from Thursday morning to Friday afternoon so the client can bring the full team.": LiveStylePromptRequirements(
            requiredFragments: ["Hey Maya", "Thursday morning", "Friday afternoon", "client can bring the full team"]
        ),
        "Please turn this into a clean update. Um the first prototype worked, the second prototype was faster, but the third prototype had the best balance between latency and quality.": LiveStylePromptRequirements(
            requiredFragments: ["first prototype", "second prototype", "third prototype", "latency and quality"]
        ),
        "Okay, the customer said they tried the feature three times, um, the first attempt failed, the second attempt worked, and the third attempt worked after they restarted the app.": LiveStylePromptRequirements(
            requiredFragments: ["3 times", "first attempt failed", "second attempt worked", "third attempt worked"]
        ),
        "I'm dictating a longer product note because I want to make sure the model can handle a real paragraph. Um the user starts by recording a thought, then chooses a vibe, then the app rewrites the text without making them leave the keyboard or guess what happened.": LiveStylePromptRequirements(
            requiredFragments: ["longer product note", "recording a thought", "chooses a vibe", "without making them leave the keyboard"]
        ),
        "This should become a support reply. Um I understand why that would be frustrating. Please send us the device model, the iOS version, and roughly what time the issue happened so we can check the logs and figure out what went wrong.": LiveStylePromptRequirements(
            requiredFragments: ["support reply", "device model", "iOS version", "check the logs"]
        ),
        "Here is the longer version for the team. Um we tested the new adapter on short messages, longer notes, grocery lists, status updates, numbers, years, prices, percentages, and messy filler, and the next step is to make sure it behaves consistently on device.": LiveStylePromptRequirements(
            requiredFragments: ["short messages", "longer notes", "grocery lists", "percentages", "consistently on device"]
        ),
        "I need this as a polished email. Um hi Taylor, thanks for the detailed feedback. I reviewed the notes from Tuesday, updated the timeline, and moved the launch review to April twenty second at eleven thirty so everyone has enough time to prepare.": LiveStylePromptRequirements(
            requiredFragments: ["Hi Taylor", "April 22nd", "11:30", "enough time to prepare"]
        ),
        "This is a very long dictated thought and it is intentionally messy because I want the test to feel closer to real usage. Um I started by thinking the feature was mostly about speed, but now I think the bigger thing is trust, because people need to know when text is editable, when a vibe is active, and when the original words are back in the field.": LiveStylePromptRequirements(
            requiredFragments: ["intentionally messy", "speed", "trust", "text is editable", "original words are back"]
        ),
        "For the internal recap, um, we shipped the first pass on Monday, reviewed twenty seven pieces of feedback on Tuesday, fixed the top five issues on Wednesday, and by Friday the average rewrite time had dropped from one point two seconds to zero point six seconds.": LiveStylePromptRequirements(
            requiredFragments: ["27 pieces of feedback", "top 5 issues", "1.2 seconds", "0.6 seconds"]
        ),
        "Please clean this up for a client update. Um we are still waiting on the final assets, but engineering finished the integration, QA found two minor issues, and the earliest realistic ship date is June fifth unless the review takes longer than expected.": LiveStylePromptRequirements(
            requiredFragments: ["final assets", "engineering finished the integration", "2 minor issues", "June 5th"]
        ),
        "Turn this into a clean note. Um the warehouse has twelve boxes ready now, another forty eight boxes arriving next week, and a back order of two hundred sixteen units that should arrive in twenty twenty six.": LiveStylePromptRequirements(
            requiredFragments: ["12 boxes", "48 boxes", "216 units", "2026"]
        ),
        "I need to capture the weird bug report. Um the user said the first dictation inserted correctly, the second one showed the yellow status label, and then after they edited the text manually the button should have gone back to the normal label color.": LiveStylePromptRequirements(
            requiredFragments: ["first dictation inserted correctly", "yellow status label", "edited the text manually", "normal label color"]
        ),
        "Draft this for the changelog. Um added support for bundled adapters, improved live model validation, expanded polished dictation coverage, and reduced ambiguity around whether the current text can still be reverted.": LiveStylePromptRequirements(
            requiredFragments: ["bundled adapters", "live model validation", "polished dictation coverage", "current text can still be reverted"]
        ),
    ]
}

private struct LiveStylePromptCase {
    let style: StyleRewriteStyle
    let input: String
    let expected: String
}

private let defaultPolishedCoverageForbiddenFragments = [
    " um",
    "um,",
    " uh",
    "uh,",
]

private struct LiveStylePromptRequirements {
    let requiredFragments: [String]
    let forbiddenFragments: [String]
    let minimumParagraphCount: Int?

    init(
        requiredFragments: [String],
        extraForbiddenFragments: [String] = [],
        minimumParagraphCount: Int? = nil
    ) {
        self.requiredFragments = requiredFragments
        self.forbiddenFragments = defaultPolishedCoverageForbiddenFragments + extraForbiddenFragments
        self.minimumParagraphCount = minimumParagraphCount
    }
}

@MainActor
private final class LiveLocalStyleResponder: TextTransformChunkResponding {
    private let model: LlamaCPULanguageModel

    init(modelURL: URL, adapterURL: URL?, adapterScale: Float) {
        self.model = LlamaCPULanguageModel(
            modelURL: modelURL,
            adapterURL: adapterURL,
            adapterScale: adapterScale
        )
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        let usesPolishedLoRA = model.hasLoRAAdapter && request.styleIdentifier == StyleRewriteStyle.polished.rawValue
        let result = try await model.generate(
            LocalLanguageModelGenerationRequest(
                systemPrompt: usesPolishedLoRA
                    ? StyleRewriteDictationConfiguration.polishedLoRASystemPrompt
                    : request.instructions,
                userPrompt: usesPolishedLoRA
                    ? chunk.text
                    : request.prompt(for: chunk.text),
                maximumTokenCount: maximumResponseTokens(for: request, chunk: chunk),
                addsSpecialTokens: !usesPolishedLoRA
            ),
            configuration: LocalLanguageModelConfiguration(
                contextTokenLimit: request.contextTokenLimit,
                threadCount: 2,
                batchThreadCount: 2,
                batchTokenCount: min(max(request.contextTokenLimit, 1), 512)
            )
        )
        return result.text
    }

    func unload() async {
        await model.unload()
    }

    private func maximumResponseTokens(
        for request: TextTransformRequest,
        chunk: TextTransformChunk
    ) -> Int {
        if let requestLimit = request.maximumResponseTokens {
            let estimatedChunkLimit = Int(
                ceil(Double(chunk.inputTokenCount) * max(request.expectedOutputExpansionRatio, 1.0))
            ) + 16
            return max(1, min(requestLimit, estimatedChunkLimit))
        }

        return 256
    }
}
