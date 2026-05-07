import Foundation
import KeyVoxLocalInference
import KeyVoxStyleRewrite

@MainActor
final class LocalStyleRewriteTextTransformer: DictationTextTransforming {
    private let inferenceService: LocalRewriteInferenceService
    private lazy var transformer = StyleRewriteTextTransformer { [weak self] _ in
        LocalStyleRewriteChunkResponder(inferenceService: self?.inferenceService)
    }

    init(inferenceService: LocalRewriteInferenceService) {
        self.inferenceService = inferenceService
    }

    func prewarm(request: TextTransformRequest) {
        transformer.prewarm(request: request)
    }

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        await transformer.transform(request)
    }
}

@MainActor
private final class LocalStyleRewriteChunkResponder: TextTransformChunkResponding {
    private let inferenceService: LocalRewriteInferenceService?

    init(inferenceService: LocalRewriteInferenceService?) {
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
            logMetrics(result.metrics, styleIdentifier: request.styleIdentifier, chunkIndex: chunk.index)
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

    private func logMetrics(
        _ metrics: LocalLanguageModelGenerationMetrics,
        styleIdentifier: String,
        chunkIndex: Int
    ) {
        #if DEBUG
        let loadDuration = metrics.loadDuration.map { String(format: "%.3f", $0) } ?? "cached"
        let tokensPerSecond = metrics.decodeTokensPerSecond.map { String(format: "%.2f", $0) } ?? "n/a"
        NSLog(
            "[StyleRewriteLocal] style=%@ chunk=%d load=%@ inputTokens=%d outputTokens=%d prefill=%.3f decode=%.3f total=%.3f tokPerSecond=%@",
            styleIdentifier,
            chunkIndex,
            loadDuration,
            metrics.inputTokenCount,
            metrics.outputTokenCount,
            metrics.prefillDuration,
            metrics.decodeDuration,
            metrics.totalDuration,
            tokensPerSecond
        )
        #endif
    }
}
