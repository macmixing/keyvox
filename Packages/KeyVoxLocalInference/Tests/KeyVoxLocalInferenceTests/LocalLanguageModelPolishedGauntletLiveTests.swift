import KeyVoxStyleRewrite
import XCTest

final class LocalLanguageModelPolishedGauntletLiveTests: XCTestCase {
    @MainActor
    func testLivePolishedGauntletWhenEnabled() async throws {
        try LocalModelLiveTestEnvironment.requireStyleTestsEnabled()
        let tester = try LiveLocalStyleTester(
            modelURL: LocalModelLiveTestEnvironment.requireModelURL(),
            adapterURL: LocalModelLiveTestEnvironment.optionalAdapterURL(),
            adapterScale: LocalModelLiveTestEnvironment.adapterScale
        )

        do {
            try await tester.assertStyleCases(
                Self.cases,
                coverageRequirements: Self.coverageRequirements
            )
            await tester.unload()
        } catch {
            await tester.unload()
            throw error
        }
    }

    private static let polishedThreeParagraphGauntletInput = "Um hey team, I looked at the April 22nd launch notes, and there are like 3 things we need to clean up. Sarah and me was reviewing the checklist at 11:30, and we found 2 minor issues. I ain't worried about the build, but the screenshots still need a final pass.\n\nOkay, so the customer paid $1,200 in twenty twenty four. They was asking whether the invoice, um, should show the discount as 15% or as $180. I seen the same confusion last week, and we should make the update clear.\n\nFor follow up, please confirm the invoice, like send the April 22nd recap, and ask Jordan if the 3 screenshots are final. We should keep the tone professional but direct. I don't want the meaning to change."

    private static let polishedFourParagraphGauntletInput = "Okay, so I guess the first thing is that the onboarding copy still feels confusing. Um users be asking why the keyboard needs full access, and that question is fair. We should explain it in 2 sentences, not 5.\n\nThe second thing is performance. Like the rewrite took 0.6 seconds on my phone, but 1 test took 1.2 seconds after the model woke up. I ain't calling that a blocker, but we should keep watching it.\n\nThird, Sarah and me was checking paragraph behavior again. The model duplicated the second paragraph once, and it dropped the first idea. That ain't acceptable because every paragraph needs to keep its own meaning.\n\nFinally, please send Maya a clean update by 3:30 tomorrow. Tell her we tested 4 longer notes, fixed 2 failures, and kept the current adapter bundled in the app. If anything changes, we can run another live test before June 5th."

    private static let cases = [
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
    ]

    private static let coverageRequirements = [
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
    ]
}
