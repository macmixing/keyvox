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
        let responder = LiveLocalStyleResponder(modelURL: modelURL)
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
}

private struct LiveStylePromptCase {
    let style: StyleRewriteStyle
    let input: String
    let expected: String
}

@MainActor
private final class LiveLocalStyleResponder: TextTransformChunkResponding {
    private let model: LlamaCPULanguageModel

    init(modelURL: URL) {
        self.model = LlamaCPULanguageModel(modelURL: modelURL)
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        let result = try await model.generate(
            LocalLanguageModelGenerationRequest(
                systemPrompt: request.instructions,
                userPrompt: request.prompt(for: chunk.text),
                maximumTokenCount: maximumResponseTokens(for: request, chunk: chunk)
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
