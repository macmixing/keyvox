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

    private let model: LlamaCPULanguageModel

    init(modelURL: URL, adapterURL: URL, adapterScale: Float) {
        self.model = LlamaCPULanguageModel(
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
