import XCTest
@testable import KeyVoxLocalInference

final class LocalLanguageModelTests: XCTestCase {
    private static let testConfiguration = LocalLanguageModelConfiguration(
        contextTokenLimit: 512,
        threadCount: 2,
        batchThreadCount: 2,
        batchTokenCount: 128
    )

    func testConfigurationKeepsCPUDefaultsWithExplicitContextLimit() {
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

    func testMissingModelProducesTypedFailure() async {
        let model = LlamaCPULanguageModel(
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
        let model = LlamaCPULanguageModel(
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

        let model = LlamaCPULanguageModel(
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
