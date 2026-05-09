import KeyVoxStyleRewrite
import XCTest
@testable import KeyVoxLocalInference

enum LocalModelLiveTestEnvironment {
    static func requireStyleTestsEnabled() throws {
        guard ProcessInfo.processInfo.environment["KEYVOX_RUN_LOCAL_STYLE_TESTS"] == "1" else {
            throw XCTSkip("Set KEYVOX_RUN_LOCAL_STYLE_TESTS=1 to run live local style prompt tests.")
        }
    }

    static func requireModelURL() throws -> URL {
        guard let modelPath = ProcessInfo.processInfo.environment["KEYVOX_LOCAL_MODEL_PATH"] else {
            throw XCTSkip("Set KEYVOX_LOCAL_MODEL_PATH to a local GGUF file.")
        }
        return URL(fileURLWithPath: modelPath)
    }

    static func optionalAdapterURL() -> URL? {
        ProcessInfo.processInfo.environment["KEYVOX_LOCAL_ADAPTER_PATH"]
            .map { URL(fileURLWithPath: $0) }
    }

    static func requireAdapterURL(description: String) throws -> URL {
        guard let adapterPath = ProcessInfo.processInfo.environment["KEYVOX_LOCAL_ADAPTER_PATH"] else {
            throw XCTSkip("Set KEYVOX_LOCAL_ADAPTER_PATH to a local \(description) adapter GGUF file.")
        }
        return URL(fileURLWithPath: adapterPath)
    }

    static var adapterScale: Float {
        ProcessInfo.processInfo.environment["KEYVOX_LOCAL_ADAPTER_SCALE"]
            .flatMap(Float.init) ?? 1.0
    }
}

struct LiveStylePromptCase {
    let style: StyleRewriteStyle
    let input: String
    let expected: String
}

let defaultPolishedCoverageForbiddenFragments = [
    " um",
    "um,",
    " uh",
    "uh,",
]

struct LiveStylePromptRequirements {
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
final class LiveLocalStyleTester {
    private let responder: LiveLocalStyleResponder
    private let transformer: StyleRewriteTextTransformer

    init(modelURL: URL, adapterURL: URL?, adapterScale: Float) {
        self.responder = LiveLocalStyleResponder(
            modelURL: modelURL,
            adapterURL: adapterURL,
            adapterScale: adapterScale
        )
        self.transformer = StyleRewriteTextTransformer(
            tokenCounter: ApproximateTextTransformTokenCounter(),
            chunkResponderProvider: { [responder] _ in responder }
        )
    }

    func assertStyleCases(
        _ cases: [LiveStylePromptCase],
        coverageRequirements: [String: LiveStylePromptRequirements] = [:],
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        var failures: [String] = []
        let styleFilter = ProcessInfo.processInfo.environment["KEYVOX_LIVE_STYLE_FILTER"]

        for testCase in cases {
            if let styleFilter, testCase.style.rawValue != styleFilter {
                continue
            }
            let request = try XCTUnwrap(
                StyleRewriteDictationConfiguration.request(
                    for: testCase.style,
                    baseText: testCase.input
                ),
                file: file,
                line: line
            )
            let result = await transformer.transform(request)
            let expectedApplied = testCase.expected != testCase.input

            if let requirements = coverageRequirements[testCase.input] {
                let missingFragments = requirements.requiredFragments.filter { !result.finalText.contains($0) }
                let presentForbiddenFragments = requirements.forbiddenFragments.filter {
                    result.finalText.localizedCaseInsensitiveContains($0)
                }
                let paragraphCount = Self.paragraphCount(in: result.finalText)
                let missedParagraphCount = requirements.minimumParagraphCount.map { paragraphCount < $0 } ?? false
                if !missingFragments.isEmpty
                    || !presentForbiddenFragments.isEmpty
                    || missedParagraphCount
                    || result.applied != expectedApplied {
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

        XCTAssertTrue(
            failures.isEmpty,
            "Production local style prompts produced unexpected outputs.\n\n\(failures.joined(separator: "\n"))",
            file: file,
            line: line
        )
    }

    func unload() async {
        await responder.unload()
    }

    private static func paragraphCount(in text: String) -> Int {
        text.components(separatedBy: "\n\n")
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .count
    }
}

@MainActor
final class LiveLocalStyleResponder: TextTransformChunkResponding {
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
