import KeyVoxStyleRewrite
import XCTest
@testable import KeyVoxLocalInference

final class LocalLanguageModelTests: XCTestCase {
    private static let testConfiguration = LocalLanguageModelConfiguration(
        contextTokenLimit: 512,
        threadCount: 2,
        batchThreadCount: 2,
        batchTokenCount: 128
    )

    func testConfigurationKeepsDefaultThreadCountsWithExplicitContextLimit() {
        let configuration = LocalLanguageModelConfiguration(contextTokenLimit: 512)

        XCTAssertEqual(configuration.contextTokenLimit, 512)
        XCTAssertEqual(configuration.threadCount, 2)
        XCTAssertEqual(configuration.batchThreadCount, 2)
        XCTAssertEqual(configuration.batchTokenCount, 512)
    }

    func testGPUOffloadModesAreEquatable() {
        XCTAssertEqual(LocalLanguageModelGPUOffloadMode.disabled, .disabled)
        XCTAssertEqual(LocalLanguageModelGPUOffloadMode.automatic, .automatic)
        XCTAssertEqual(LocalLanguageModelGPUOffloadMode.allLayers, .allLayers)
        XCTAssertEqual(LocalLanguageModelGPUOffloadMode.layerCount(12), .layerCount(12))
        XCTAssertNotEqual(LocalLanguageModelGPUOffloadMode.layerCount(12), .layerCount(13))
    }

    func testMetricsComputeDecodeTokensPerSecond() {
        let metrics = LocalLanguageModelGenerationMetrics(
            loadDuration: 0.5,
            inputTokenCount: 10,
            outputTokenCount: 20,
            prefillDuration: 0.25,
            decodeDuration: 2,
            totalDuration: 2.75
        )

        XCTAssertEqual(metrics.decodeTokensPerSecond, 10)
        XCTAssertFalse(metrics.reachedMaximumTokenCount)
    }

    func testOutputTruncatedErrorIsTyped() {
        XCTAssertEqual(
            LocalLanguageModelError.outputTruncated(maximumTokenCount: 12).description,
            "outputTruncated(maximumTokenCount=12)"
        )
    }

    func testStructuredChatRequestStoresSeparateSystemAndUserPrompts() {
        let request = LocalLanguageModelGenerationRequest(
            systemPrompt: "System instructions",
            userPrompt: "User input",
            maximumTokenCount: 8
        )

        XCTAssertEqual(request.prompt, "User input")
        XCTAssertEqual(request.systemPrompt, "System instructions")
        XCTAssertEqual(request.userPrompt, "User input")
        XCTAssertTrue(request.usesChatTemplate)
        XCTAssertTrue(request.addsSpecialTokens)
    }

    func testCancellationTokenThrowsTypedCancellation() {
        let token = LocalInferenceCancellationToken()
        token.cancel()

        XCTAssertThrowsError(try token.checkCancellation()) { error in
            XCTAssertEqual(error as? LocalLanguageModelError, .cancelled)
        }
    }

    @MainActor
    func testStyleRewriteDependencyRepairsAddressOrdinalDrift() async throws {
        let request = try XCTUnwrap(StyleRewriteDictationConfiguration.request(
            for: .polished,
            baseText: "She said her address was eleven thirty seven North Twelfth Street."
        ))
        let transformer = StyleRewriteTextTransformer(
            tokenCounter: LocalInferenceWordTokenCounter(),
            chunkResponderProvider: { _ in
                LocalInferenceStubChunkResponder(response: "She said her address was 1137 North 2nd Street.")
            }
        )

        let result = await transformer.transform(request)

        XCTAssertEqual(result.finalText, "She said her address was 1137 North 12th Street.")
    }

    func testMissingModelProducesTypedFailure() async {
        let model = LlamaLocalLanguageModel(
            modelURL: URL(fileURLWithPath: "/tmp/keyvox-missing-local-model.gguf")
        )

        do {
            _ = try await model.generate(
                LocalLanguageModelGenerationRequest(
                    prompt: "Hello",
                    maximumTokenCount: 4
                ),
                configuration: Self.testConfiguration
            )
            XCTFail("Expected missing model failure.")
        } catch {
            XCTAssertEqual(error as? LocalLanguageModelError, .modelFileMissing)
        }
    }

    func testPrepareMissingModelProducesTypedFailure() async {
        let model = LlamaLocalLanguageModel(
            modelURL: URL(fileURLWithPath: "/tmp/keyvox-missing-local-model.gguf")
        )

        do {
            _ = try await model.prepare(configuration: Self.testConfiguration)
            XCTFail("Expected missing model failure.")
        } catch {
            XCTAssertEqual(error as? LocalLanguageModelError, .modelFileMissing)
        }
    }

    func testLiveLocalModelGeneratesWhenEnabled() async throws {
        guard ProcessInfo.processInfo.environment["KEYVOX_RUN_LOCAL_MODEL_LIVE_TESTS"] == "1" else {
            throw XCTSkip("Set KEYVOX_RUN_LOCAL_MODEL_LIVE_TESTS=1 to run the live local model test.")
        }
        guard let modelPath = ProcessInfo.processInfo.environment["KEYVOX_LOCAL_MODEL_PATH"] else {
            throw XCTSkip("Set KEYVOX_LOCAL_MODEL_PATH to a local GGUF file.")
        }

        let model = LlamaLocalLanguageModel(
            modelURL: URL(fileURLWithPath: modelPath),
            gpuOffloadMode: .automatic
        )
        do {
            let result = try await model.generate(
                LocalLanguageModelGenerationRequest(
                    prompt: "Return only the word ready.",
                    maximumTokenCount: 8
                ),
                configuration: Self.testConfiguration
            )
            await model.unload()

            XCTAssertFalse(result.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertGreaterThan(result.metrics.outputTokenCount, 0)
        } catch {
            await model.unload()
            throw error
        }
    }

}

private struct LocalInferenceWordTokenCounter: TextTransformTokenCounting {
    func tokenCount(for text: String) async throws -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }
}

@MainActor
private final class LocalInferenceStubChunkResponder: TextTransformChunkResponding {
    private let response: String

    init(response: String) {
        self.response = response
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        response
    }
}
