import Foundation
import KeyVoxLocalInference
import KeyVoxStyleRewrite

@MainActor
final class KeyboardLocalStyleRewriteTextTransformer: DictationTextTransforming {
    private let inferenceService: KeyboardLocalRewriteInferenceService
    private lazy var transformer = StyleRewriteTextTransformer { [weak self] _ in
        KeyboardLocalStyleRewriteChunkResponder(inferenceService: self?.inferenceService)
    }

    init() {
        self.inferenceService = KeyboardLocalRewriteInferenceService()
    }

    func prewarm(request: TextTransformRequest) {
        transformer.prewarm(request: request)
    }

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        await transformer.transform(request)
    }

    func releasePrewarmSession(reason: String) {}
}

@MainActor
private final class KeyboardLocalRewriteInferenceService {
    private let fileManager: FileManager
    private var loadedModelURL: URL?
    private var loadedModel: LlamaCPULanguageModel?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func model() throws -> LlamaCPULanguageModel {
        guard let modelURL = installedModelURL() else {
            throw KeyboardLocalRewriteInferenceServiceError.modelNotInstalled
        }

        if loadedModelURL != modelURL {
            loadedModel = LlamaCPULanguageModel(modelURL: modelURL)
            loadedModelURL = modelURL
        }

        guard let loadedModel else {
            throw KeyboardLocalRewriteInferenceServiceError.modelNotInstalled
        }

        return loadedModel
    }

    private func installedModelURL() -> URL? {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: KeyVoxIPCBridge.appGroupID
        ) else {
            return nil
        }

        let modelURL = containerURL
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("rewrite", isDirectory: true)
            .appendingPathComponent("qwen2-5-0-5b-instruct", isDirectory: true)
            .appendingPathComponent("qwen2.5-0.5b-instruct-q4_k_m.gguf", isDirectory: false)

        return fileManager.fileExists(atPath: modelURL.path) ? modelURL : nil
    }
}

private enum KeyboardLocalRewriteInferenceServiceError: Error {
    case modelNotInstalled
}

@MainActor
private final class KeyboardLocalStyleRewriteChunkResponder: TextTransformChunkResponding {
    private let inferenceService: KeyboardLocalRewriteInferenceService?

    init(inferenceService: KeyboardLocalRewriteInferenceService?) {
        self.inferenceService = inferenceService
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        guard let inferenceService else {
            throw StyleRewriteBackendError.modelNotInstalled
        }

        let model: LlamaCPULanguageModel
        do {
            model = try inferenceService.model()
        } catch {
            throw StyleRewriteBackendError.modelNotInstalled
        }

        do {
            let localRequest = LocalLanguageModelGenerationRequest(
                systemPrompt: request.instructions,
                userPrompt: request.prompt(for: chunk.text),
                maximumTokenCount: maximumResponseTokens(for: request, chunk: chunk)
            )
            let result = try await model.generate(
                localRequest,
                configuration: LocalLanguageModelConfiguration(
                    contextTokenLimit: request.contextTokenLimit,
                    threadCount: 2,
                    batchThreadCount: 2,
                    batchTokenCount: min(max(request.contextTokenLimit, 1), 512)
                )
            )
            return result.text
        } catch let error as LocalLanguageModelError {
            throw mapLocalInferenceError(error)
        } catch {
            throw StyleRewriteBackendError.generationFailed(String(describing: error))
        }
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

    private func mapLocalInferenceError(_ error: LocalLanguageModelError) -> StyleRewriteBackendError {
        switch error {
        case .modelFileMissing:
            return .modelNotInstalled
        case .modelLoadFailed, .contextCreateFailed:
            return .modelLoadFailed(error.description)
        case .promptTooLong:
            return .promptTooLong(error.description)
        case .cancelled:
            return .cancelled
        case .tokenizerFailed, .decodeFailed, .emptyOutput:
            return .generationFailed(error.description)
        }
    }
}
