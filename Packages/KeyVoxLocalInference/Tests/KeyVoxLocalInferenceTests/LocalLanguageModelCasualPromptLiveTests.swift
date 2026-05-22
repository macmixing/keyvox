import KeyVoxStyleRewrite
import XCTest
@testable import KeyVoxLocalInference

final class LocalLanguageModelCasualPromptLiveTests: XCTestCase {
    @MainActor
    func testLiveCasualCoverageWhenEnabled() async throws {
        let tester = try Self.makeTester()

        let cases: [CasualLiveCase] = [
            CasualLiveCase(
                input: "Hey, um, like are you coming over later?",
                requiredFragments: ["Hey", "like are you coming over later"],
                forbiddenFragments: ["um"]
            ),
            CasualLiveCase(
                input: "I ain't doing that today.",
                requiredFragments: ["I ain't doing that today"],
                forbiddenFragments: ["I'm not", "I am not"]
            ),
            CasualLiveCase(
                input: "What you be doing after work?",
                requiredFragments: ["What you be doing after work"],
                forbiddenFragments: ["What are you doing"]
            ),
            CasualLiveCase(
                input: "Sarah and me was testing the keyboard.",
                requiredFragments: ["Sarah and me was testing the keyboard"],
                forbiddenFragments: ["Sarah and I", "were testing"]
            ),
            CasualLiveCase(
                input: "Why the fuck is this button still weird?",
                requiredFragments: ["Why the fuck is this button still weird"],
                forbiddenFragments: []
            ),
            CasualLiveCase(
                input: "I need groceries:\n\n1. Um apples\n2. Like bananas\n3. Uh grapes",
                requiredFragments: ["1. Apples", "2. Like bananas", "3. Grapes"],
                forbiddenFragments: ["Um apples", "Uh grapes"],
                minimumParagraphCount: 2
            ),
            CasualLiveCase(
                input: "Move the call to 11:30 and send the one hundred eighty dollar invoice.",
                requiredFragments: ["11:30", "$180"],
                forbiddenFragments: ["one hundred eighty"]
            ),
            CasualLiveCase(
                input: "Um I tested this for a little bit, and like it mostly works.\n\nUh the second paragraph should stay separate and keep the same meaning.",
                requiredFragments: ["I tested this for a little bit", "like it mostly works", "The second paragraph should stay separate"],
                forbiddenFragments: ["Um", "Uh"],
                minimumParagraphCount: 2
            ),
        ]

        do {
            try await tester.assertCases(cases)
            await tester.unload()
        } catch {
            await tester.unload()
            throw error
        }
    }

    @MainActor
    func testLiveCasualSpokenTimeCoverageWhenEnabled() async throws {
        let tester = try Self.makeTester()

        let cases: [CasualLiveCase] = [
            CasualLiveCase(
                input: "Hey, can you meet me for lunch tomorrow at three fifteen?",
                requiredFragments: ["3:15"],
                forbiddenFragments: ["3:10", "three fifteen"]
            ),
            CasualLiveCase(
                input: "Hey, can you meet me for lunch tomorrow at four forty five?",
                requiredFragments: ["4:45"],
                forbiddenFragments: ["4:05", "four forty five"]
            ),
            CasualLiveCase(
                input: "Uh remind me to check the build at seven twenty five.",
                requiredFragments: ["7:25"],
                forbiddenFragments: ["seven twenty five", "7:20"]
            ),
            CasualLiveCase(
                input: "Like can we talk at two oh five about the keyboard?",
                requiredFragments: ["Like can we talk at 2:05"],
                forbiddenFragments: ["two oh five", "2:50"]
            ),
            CasualLiveCase(
                input: "Sarah and me was going to meet at eleven thirty five.",
                requiredFragments: ["Sarah and me was going to meet at 11:35"],
                forbiddenFragments: ["Sarah and I", "eleven thirty five"]
            ),
            CasualLiveCase(
                input: "I ain't showing up before twelve fifty.",
                requiredFragments: ["I ain't showing up before 12:50"],
                forbiddenFragments: ["I'm not", "twelve fifty"]
            ),
            CasualLiveCase(
                input: "This shit needs to be done by nine forty.",
                requiredFragments: ["This shit needs to be done by 9:40"],
                forbiddenFragments: ["nine forty"]
            ),
            CasualLiveCase(
                input: "Move the follow up to six fifty five and keep it casual.",
                requiredFragments: ["6:55"],
                forbiddenFragments: ["six fifty five"]
            ),
            CasualLiveCase(
                input: "It feels like we've been doing this since twenty twelve, but it's only twenty eighteen.",
                requiredFragments: ["since 2012", "only 2018"],
                forbiddenFragments: ["2022", "2028", "twenty twelve", "twenty eighteen"]
            ),
            CasualLiveCase(
                input: "I can't believe we haven't done that since what, twenty twelve?",
                requiredFragments: ["since what, 2012"],
                forbiddenFragments: ["2022", "twenty twelve"]
            ),
            CasualLiveCase(
                input: "The audit started in twenty eighteen and wrapped up in twenty nineteen.",
                requiredFragments: ["2018", "2019"],
                forbiddenFragments: ["2028", "2029", "twenty eighteen", "twenty nineteen"]
            ),
            CasualLiveCase(
                input: "The team closed twenty two tickets, reviewed twenty eight screenshots, and ordered twenty five labels.",
                requiredFragments: ["22 tickets", "28 screenshots", "25 labels"],
                forbiddenFragments: ["2022", "2028", "2025"]
            ),
        ]

        do {
            try await tester.assertCases(cases)
            await tester.unload()
        } catch {
            await tester.unload()
            throw error
        }
    }

    @MainActor
    func testLiveCasualMoneyBoundaryCoverageWhenEnabled() async throws {
        let tester = try Self.makeTester()

        let cases: [CasualLiveCase] = [
            CasualLiveCase(
                input: "Meet me at 655 East Clifford Drive.",
                requiredFragments: ["655 East Clifford Drive"],
                forbiddenFragments: ["6:55 East Clifford Drive", "six fifty five"]
            ),
            CasualLiveCase(
                input: "Meet me at six fifty five East Clifford Drive.",
                requiredFragments: ["655 East Clifford Drive"],
                forbiddenFragments: ["6:55 East Clifford Drive", "six fifty five"]
            ),
            CasualLiveCase(
                input: "Meet me at six five five East Clifford Drive.",
                requiredFragments: ["655 East Clifford Drive"],
                forbiddenFragments: ["6:55 East Clifford Drive", "six five five"]
            ),
            CasualLiveCase(
                input: "Meet me at 652 North Washington Street.",
                requiredFragments: ["652 North Washington Street"],
                forbiddenFragments: ["6:52 North Washington Street", "six fifty two"]
            ),
            CasualLiveCase(
                input: "Meet me at six fifty two North Washington Street.",
                requiredFragments: ["652 North Washington Street"],
                forbiddenFragments: ["6:52 North Washington Street", "six fifty two"]
            ),
            CasualLiveCase(
                input: "Meet me at 852 West General Street.",
                requiredFragments: ["852 West General Street"],
                forbiddenFragments: ["8:52 West General Street", "eight fifty two"]
            ),
            CasualLiveCase(
                input: "Meet me at eight fifty two West General Street.",
                requiredFragments: ["852 West General Street"],
                forbiddenFragments: ["8:52 West General Street", "eight fifty two"]
            ),
            CasualLiveCase(
                input: "Drop the package at 734 South Maple Avenue.",
                requiredFragments: ["734 South Maple Avenue"],
                forbiddenFragments: ["7:34 South Maple Avenue", "seven thirty four"]
            ),
            CasualLiveCase(
                input: "Meet me at 1,152 North Washington Street.",
                requiredFragments: ["1152 North Washington Street"],
                forbiddenFragments: ["1,152", "11:52 North Washington"]
            ),
            CasualLiveCase(
                input: "Meet me at eleven fifty two North Washington Street.",
                requiredFragments: ["1152 North Washington Street"],
                forbiddenFragments: ["11:52 North Washington", "eleven fifty two"]
            ),
            CasualLiveCase(
                input: "Send it to 1,034 West General Street.",
                requiredFragments: ["1034 West General Street"],
                forbiddenFragments: ["1,034", "10:34 West General"]
            ),
            CasualLiveCase(
                input: "Meet me at ten thirty four West General Street.",
                requiredFragments: ["1034 West General Street"],
                forbiddenFragments: ["10:34 West General", "ten thirty four"]
            ),
            CasualLiveCase(
                input: "Meet me at 655 East Clifford Drive at three thirty.",
                requiredFragments: ["655 East Clifford Drive", "at 3:30"],
                forbiddenFragments: ["6:55 East Clifford Drive", "three thirty"]
            ),
            CasualLiveCase(
                input: "The appointment is at three thirty at 652 North Washington Street.",
                requiredFragments: ["at 3:30", "652 North Washington Street"],
                forbiddenFragments: ["6:52 North Washington Street", "three thirty"]
            ),
            CasualLiveCase(
                input: "Meet me at eleven fifty two North Washington Street at three thirty.",
                requiredFragments: ["1152 North Washington Street", "at 3:30"],
                forbiddenFragments: ["11:52 North Washington", "eleven fifty two", "three thirty"]
            ),
            CasualLiveCase(
                input: "She said her address was eleven twenty five North Twelfth Street.",
                requiredFragments: ["1125 North 12th Street"],
                forbiddenFragments: ["1125 North Twelfth Street", "125 North 2nd Street", "North 2nd Street"]
            ),
            CasualLiveCase(
                input: "She said her address was eleven thirty seven North Twelfth Street.",
                requiredFragments: ["1137 North 12th Street"],
                forbiddenFragments: ["1137 North Twelfth Street", "1137 North 2nd Street", "North 2nd Street"]
            ),
            CasualLiveCase(
                input: "I'm pretty sure that ain't twenty-five dollars, but I definitely know it starts at three thirty.",
                requiredFragments: ["ain't $25", "starts at 3:30"],
                forbiddenFragments: ["25 dollars", "$3.30", "twenty-five dollars", "three thirty"]
            ),
            CasualLiveCase(
                input: "I'm pretty sure that ain't thirty-five dollars, but I definitely know it starts at five thirty.",
                requiredFragments: ["ain't $35", "starts at 5:30"],
                forbiddenFragments: ["35 dollars", "$5.30", "thirty-five dollars", "five thirty"]
            ),
            CasualLiveCase(
                input: "I'm pretty sure that isn't forty dollars, but I definitely know it starts at six fifteen.",
                requiredFragments: ["isn't $40", "starts at 6:15"],
                forbiddenFragments: ["40 dollars", "$6.15", "forty dollars", "six fifteen"]
            ),
            CasualLiveCase(
                input: "The price is not forty-five dollars, and the start time is seven forty five.",
                requiredFragments: ["not $45", "start time is 7:45"],
                forbiddenFragments: ["45 dollars", "$7.45", "forty-five dollars", "seven forty five"]
            ),
            CasualLiveCase(
                input: "The ticket price should be thirty-five dollars, and the event starts at five thirty.",
                requiredFragments: ["price should be $35", "starts at 5:30"],
                forbiddenFragments: ["35 dollars", "$5.30", "thirty-five dollars", "five thirty"]
            ),
            CasualLiveCase(
                input: "Tell John the concert ain't five dollars, but it'll be three dollars.",
                requiredFragments: ["ain't $5", "it'll be $3"],
                forbiddenFragments: ["$50", "five dollars", "three dollars"]
            ),
            CasualLiveCase(
                input: "Tell John the concert is three dollars, not five dollars.",
                requiredFragments: ["$3", "not $5"],
                forbiddenFragments: ["three dollars", "five dollars"]
            ),
            CasualLiveCase(
                input: "Um I'm pretty sure that's like twenty-five dollars and starts at three thirty.",
                requiredFragments: ["I'm pretty sure that's like $25", "starts at 3:30"],
                forbiddenFragments: ["205", "twenty-five dollars", "three thirty"]
            ),
            CasualLiveCase(
                input: "Um I'm pretty sure that's like twenty dollars and starts at three thirty.",
                requiredFragments: ["I'm pretty sure that's like $20", "starts at 3:30"],
                forbiddenFragments: ["20 dollars", "twenty dollars", "three thirty"]
            ),
            CasualLiveCase(
                input: "Tell John the tickets were five dollars yesterday and three dollars today.",
                requiredFragments: ["$5 yesterday", "$3 today"],
                forbiddenFragments: ["$50", "five dollars", "three dollars"]
            ),
            CasualLiveCase(
                input: "I'm pretty sure that's like twenty-five dollars, not twenty dollars.",
                requiredFragments: ["like $25", "not $20"],
                forbiddenFragments: ["205", "twenty-five dollars", "twenty dollars"]
            ),
            CasualLiveCase(
                input: "I would have spent fifty dollars seven days ago.",
                requiredFragments: ["$50 seven days ago"],
                forbiddenFragments: ["$5007", "$50 7 days ago", "fifty dollars seven days ago"]
            ),
            CasualLiveCase(
                input: "I would have spent one hundred dollars seven days ago.",
                requiredFragments: ["$100 seven days ago"],
                forbiddenFragments: ["$107 days ago", "$100 7 days ago", "one hundred dollars seven days ago"]
            ),
            CasualLiveCase(
                input: "I would have spent forty-three dollars seven days ago.",
                requiredFragments: ["$43 seven days ago"],
                forbiddenFragments: ["$4307", "$43 7 days ago", "forty-three dollars seven days ago"]
            ),
            CasualLiveCase(
                input: "I ended up getting ten for one dollar.",
                requiredFragments: ["10 for $1"],
                forbiddenFragments: ["10 for $100", "ten for one dollar"]
            ),
            CasualLiveCase(
                input: "It probably would have cost fifty dollars three days ago.",
                requiredFragments: ["$50 three days ago"],
                forbiddenFragments: ["$5003", "$50 3 days ago", "fifty dollars three days ago"]
            ),
            CasualLiveCase(
                input: "Yeah, that was what? Fifty dollars multiplied by three?",
                requiredFragments: ["Yeah, that was what? $50 multiplied by three?"],
                forbiddenFragments: ["$500 multiplied by 3", "$50 multiplied by 3", "Fifty dollars multiplied by three"]
            ),
            CasualLiveCase(
                input: "Yeah, that was 3 * 50 dollars.",
                requiredFragments: ["Yeah, that was 3 * $50"],
                forbiddenFragments: ["$3 * $500", "3 * 50 dollars"]
            ),
            CasualLiveCase(
                input: "What yeah, that was 3 * 57 dollars.",
                requiredFragments: ["What yeah, that was 3 * $57"],
                forbiddenFragments: ["$3 * $570", "3 * 57 dollars"]
            ),
        ]

        do {
            try await tester.assertCases(cases)
            await tester.unload()
        } catch {
            await tester.unload()
            throw error
        }
    }

    @MainActor
    func testLiveCasualGauntletWhenEnabled() async throws {
        let tester = try Self.makeTester()

        let cases: [CasualLiveCase] = [
            CasualLiveCase(
                input: "Um okay, like I tested the adapter for 20 minutes, and I ain't saying it's perfect. Sarah and me was trying a few weird cases, and what you be doing matters less than whether the words stay put.\n\nUh the list still needs to work:\n\n1. Like apples\n2. Um bananas\n3. Fucking grapes\n\nHm the final note is that the invoice shows $180, the date is April 22nd, and the follow up is at 11:30.",
                requiredFragments: [
                    "like I tested the adapter for 20 minutes",
                    "I ain't saying it's perfect",
                    "Sarah and me was trying",
                    "what you be doing",
                    "1. Like apples",
                    "2. Bananas",
                    "3. Fucking grapes",
                    "$180",
                    "April 22nd",
                    "11:30",
                ],
                forbiddenFragments: [
                    "I'm not saying",
                    "Sarah and I",
                    "what you are doing",
                    "Um",
                    "Uh",
                    "Hm",
                ],
                minimumParagraphCount: 4
            ),
            CasualLiveCase(
                input: "Uh first paragraph is just me talking like normal, and this shit should not get polished. I ain't trying to make it sound fancy.\n\nUm second paragraph has Sarah and me was checking the status label, and they was looking at the old text. Like the whole point is to keep the voice.\n\nHm third paragraph has a list:\n\n- Um full access copy\n- Like yellow label state\n- Uh undo behavior\n\nAh fourth paragraph says the total is five hundred dollars, the renewal is twenty twenty four, and the meeting is at 3:30.",
                requiredFragments: [
                    "this shit should not get polished",
                    "I ain't trying to make it sound fancy",
                    "Sarah and me was checking",
                    "they was looking",
                    "Like the whole point",
                    "- Full access copy",
                    "- Like yellow label state",
                    "- Undo behavior",
                    "$500",
                    "2024",
                    "3:30",
                ],
                forbiddenFragments: [
                    "I'm not trying",
                    "Sarah and I",
                    "they were looking",
                    "professionally",
                    "Uh",
                    "Um",
                    "Hm",
                ],
                minimumParagraphCount: 5
            ),
        ]

        do {
            try await tester.assertCases(cases)
            await tester.unload()
        } catch {
            await tester.unload()
            throw error
        }
    }

    @MainActor
    private static func makeTester() throws -> CasualLiveTester {
        guard ProcessInfo.processInfo.environment["KEYVOX_RUN_LOCAL_STYLE_TESTS"] == "1" else {
            throw XCTSkip("Set KEYVOX_RUN_LOCAL_STYLE_TESTS=1 to run live local style prompt tests.")
        }
        guard let modelPath = ProcessInfo.processInfo.environment["KEYVOX_LOCAL_MODEL_PATH"] else {
            throw XCTSkip("Set KEYVOX_LOCAL_MODEL_PATH to a local GGUF file.")
        }
        guard let adapterPath = ProcessInfo.processInfo.environment["KEYVOX_LOCAL_ADAPTER_PATH"] else {
            throw XCTSkip("Set KEYVOX_LOCAL_ADAPTER_PATH to a local Casual adapter GGUF file.")
        }

        return CasualLiveTester(
            modelURL: URL(fileURLWithPath: modelPath),
            adapterURL: URL(fileURLWithPath: adapterPath),
            adapterScale: ProcessInfo.processInfo.environment["KEYVOX_LOCAL_ADAPTER_SCALE"]
                .flatMap(Float.init) ?? 1.0
        )
    }
}

private struct CasualLiveCase {
    let input: String
    let requiredFragments: [String]
    let forbiddenFragments: [String]
    let minimumParagraphCount: Int?

    init(
        input: String,
        requiredFragments: [String],
        forbiddenFragments: [String],
        minimumParagraphCount: Int? = nil
    ) {
        self.input = input
        self.requiredFragments = requiredFragments
        self.forbiddenFragments = forbiddenFragments
        self.minimumParagraphCount = minimumParagraphCount
    }
}

@MainActor
private final class CasualLiveTester {
    private let responder: CasualLiveResponder
    private let transformer: StyleRewriteTextTransformer

    init(modelURL: URL, adapterURL: URL, adapterScale: Float) {
        self.responder = CasualLiveResponder(
            modelURL: modelURL,
            adapterURL: adapterURL,
            adapterScale: adapterScale
        )
        self.transformer = StyleRewriteTextTransformer(
            tokenCounter: ApproximateTextTransformTokenCounter(),
            chunkResponderProvider: { [responder] _ in responder }
        )
    }

    func assertCases(_ cases: [CasualLiveCase], file: StaticString = #filePath, line: UInt = #line) async throws {
        var failures: [String] = []
        for testCase in cases {
            let request = try XCTUnwrap(
                StyleRewriteDictationConfiguration.request(for: .casual, baseText: testCase.input),
                file: file,
                line: line
            )
            let result = await transformer.transform(request)
            let missingFragments = testCase.requiredFragments.filter { !result.finalText.contains($0) }
            let presentForbiddenFragments = testCase.forbiddenFragments.filter {
                result.finalText.localizedCaseInsensitiveContains($0)
            }
            let paragraphCount = result.finalText
                .components(separatedBy: "\n\n")
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .count
            let missedParagraphCount = testCase.minimumParagraphCount.map { paragraphCount < $0 } ?? false

            if !missingFragments.isEmpty || !presentForbiddenFragments.isEmpty || missedParagraphCount {
                failures.append(
                    "\(testCase.input) => \(result.finalText); missing=\(missingFragments); forbidden=\(presentForbiddenFragments); paragraphs=\(paragraphCount)"
                )
            }
        }

        XCTAssertTrue(
            failures.isEmpty,
            "Casual LoRA live outputs failed requirements.\n\n\(failures.joined(separator: "\n"))",
            file: file,
            line: line
        )
    }

    func unload() async {
        await responder.unload()
    }
}

@MainActor
private final class CasualLiveResponder: TextTransformChunkResponding {
    private static let casualLoRASystemPrompt = "Lightly clean this dictated text. Remove clear filler except keep the word like. Preserve slang, profanity, grammar, meaning, lists, and paragraph breaks. Format numbers, dates, money, and percentages when clear. Output only the result."

    private let model: LlamaLocalLanguageModel

    init(modelURL: URL, adapterURL: URL, adapterScale: Float) {
        self.model = LlamaLocalLanguageModel(
            modelURL: modelURL,
            adapterURL: adapterURL,
            adapterScale: adapterScale
        )
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        let result = try await model.generate(
            LocalLanguageModelGenerationRequest(
                systemPrompt: Self.casualLoRASystemPrompt,
                userPrompt: chunk.text,
                maximumTokenCount: maximumResponseTokens(for: request, chunk: chunk),
                addsSpecialTokens: false
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
