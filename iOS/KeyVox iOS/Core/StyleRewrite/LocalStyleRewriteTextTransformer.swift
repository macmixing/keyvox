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

        let adapterKind = Self.adapterKind(for: request.styleIdentifier)
        let model: LlamaCPULanguageModel
        do {
            model = try inferenceService.model(adapter: adapterKind)
        } catch LocalRewriteInferenceServiceError.adapterNotInstalled(let adapter) {
            logLoRAMissing(styleIdentifier: request.styleIdentifier, chunkIndex: chunk.index, adapter: adapter)
            throw StyleRewriteBackendError.modelLoadFailed("\(adapter.logLabel)AdapterNotInstalled")
        } catch LocalRewriteInferenceServiceError.modelNotInstalled {
            throw StyleRewriteBackendError.modelNotInstalled
        } catch {
            throw StyleRewriteBackendError.modelNotInstalled
        }

        do {
            let localRequest = LocalLanguageModelGenerationRequest(
                systemPrompt: systemPrompt(for: request, adapterKind: adapterKind),
                userPrompt: adapterKind == nil ? request.prompt(for: chunk.text) : chunk.text,
                maximumTokenCount: maximumResponseTokens(for: request, chunk: chunk),
                addsSpecialTokens: adapterKind == nil
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
            logMetrics(
                result.metrics,
                styleIdentifier: request.styleIdentifier,
                chunkIndex: chunk.index,
                adapterKind: adapterKind
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
        case .modelLoadFailed, .adapterFileMissing, .adapterLoadFailed, .adapterAttachFailed, .contextCreateFailed:
            return .modelLoadFailed(error.description)
        case .promptTooLong:
            return .promptTooLong(error.description)
        case .cancelled:
            return .cancelled
        case .tokenizerFailed, .decodeFailed, .emptyOutput:
            return .generationFailed(error.description)
        }
    }

    private static func adapterKind(for styleIdentifier: String) -> LocalRewriteAdapterKind? {
        switch styleIdentifier {
        case StyleRewriteStyle.polished.styleIdentifier:
            return .polished
        case StyleRewriteStyle.casual.styleIdentifier, StyleRewriteStyle.chill.styleIdentifier:
            return .casual
        default:
            return nil
        }
    }

    private func systemPrompt(
        for request: TextTransformRequest,
        adapterKind: LocalRewriteAdapterKind?
    ) -> String {
        switch adapterKind {
        case .polished:
            return StyleRewriteDictationConfiguration.polishedLoRASystemPrompt
        case .casual:
            return StyleRewriteDictationConfiguration.casualLoRASystemPrompt
        case nil:
            return request.instructions
        }
    }

    private func logMetrics(
        _ metrics: LocalLanguageModelGenerationMetrics,
        styleIdentifier: String,
        chunkIndex: Int,
        adapterKind: LocalRewriteAdapterKind?
    ) {
        #if DEBUG
        let loadDuration = metrics.loadDuration.map { String(format: "%.3f", $0) } ?? "cached"
        let tokensPerSecond = metrics.decodeTokensPerSecond.map { String(format: "%.2f", $0) } ?? "n/a"
        NSLog(
            "[StyleRewriteLocal] style=%@ chunk=%d lora=%@ load=%@ inputTokens=%d outputTokens=%d prefill=%.3f decode=%.3f total=%.3f tokPerSecond=%@",
            styleIdentifier,
            chunkIndex,
            adapterKind?.logLabel ?? "none",
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

    private func logLoRAMissing(
        styleIdentifier: String,
        chunkIndex: Int,
        adapter: LocalRewriteAdapterKind
    ) {
        #if DEBUG
        NSLog(
            "[StyleRewriteLocal] style=%@ chunk=%d lora=%@ missing",
            styleIdentifier,
            chunkIndex,
            adapter.logLabel
        )
        #endif
    }
}

private extension LocalRewriteAdapterKind {
    var logLabel: String {
        switch self {
        case .polished:
            return "polished-alpha-021"
        case .casual:
            return "casual-alpha-1"
        }
    }
}
