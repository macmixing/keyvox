import Foundation
import KeyVoxLocalInference
import KeyVoxStyleRewrite

@MainActor
final class MacLocalStyleRewriteTextTransformer: DictationTextTransforming {
    private let inferenceService: MacLocalRewriteInferenceService
    private lazy var transformer = StyleRewriteTextTransformer { [weak self] _ in
        MacLocalStyleRewriteChunkResponder(inferenceService: self?.inferenceService)
    }

    init(inferenceService: MacLocalRewriteInferenceService) {
        self.inferenceService = inferenceService
    }

    func prewarm(request: TextTransformRequest) {
        let adapterKind = macLocalRewriteAdapterKind(for: request.styleIdentifier)
        Task { @MainActor [inferenceService] in
            do {
                let model = try inferenceService.model(adapter: adapterKind)
                let result = try await model.prepare(
                    configuration: LocalLanguageModelConfiguration(
                        contextTokenLimit: request.contextTokenLimit,
                        threadCount: 2,
                        batchThreadCount: 2,
                        batchTokenCount: min(max(request.contextTokenLimit, 1), 512)
                    )
                )
                logMacLocalPrewarm(
                    styleIdentifier: request.styleIdentifier,
                    adapterKind: adapterKind,
                    loadDuration: result.loadDuration
                )
            } catch {
                logMacLocalPrewarmFailure(
                    styleIdentifier: request.styleIdentifier,
                    adapterKind: adapterKind,
                    error: error
                )
            }
        }
    }

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        await transformer.transform(request)
    }
}

@MainActor
private final class MacLocalStyleRewriteChunkResponder: TextTransformChunkResponding {
    private let inferenceService: MacLocalRewriteInferenceService?

    init(inferenceService: MacLocalRewriteInferenceService?) {
        self.inferenceService = inferenceService
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        guard let inferenceService else {
            throw StyleRewriteBackendError.modelNotInstalled
        }

        let adapterKind = macLocalRewriteAdapterKind(for: request.styleIdentifier)
        let model: LlamaCPULanguageModel
        do {
            model = try inferenceService.model(adapter: adapterKind)
        } catch MacLocalRewriteInferenceServiceError.adapterNotInstalled(let adapter) {
            logMacLocalLoRAMissing(
                styleIdentifier: request.styleIdentifier,
                chunkIndex: chunk.index,
                adapter: adapter
            )
            throw StyleRewriteBackendError.modelLoadFailed("\(adapter.logLabel)AdapterNotInstalled")
        } catch MacLocalRewriteInferenceServiceError.modelNotInstalled {
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
            logMacLocalMetrics(
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

    private func systemPrompt(
        for request: TextTransformRequest,
        adapterKind: MacLocalRewriteAdapterKind?
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
}

private func macLocalRewriteAdapterKind(for styleIdentifier: String) -> MacLocalRewriteAdapterKind? {
    switch styleIdentifier {
    case StyleRewriteStyle.polished.styleIdentifier:
        return .polished
    case StyleRewriteStyle.casual.styleIdentifier, StyleRewriteStyle.chill.styleIdentifier:
        return .casual
    default:
        return nil
    }
}

private func logMacLocalMetrics(
    _ metrics: LocalLanguageModelGenerationMetrics,
    styleIdentifier: String,
    chunkIndex: Int,
    adapterKind: MacLocalRewriteAdapterKind?
) {
    #if DEBUG
    let loadDuration = metrics.loadDuration.map { String(format: "%.3f", $0) } ?? "cached"
    let tokensPerSecond = metrics.decodeTokensPerSecond.map { String(format: "%.2f", $0) } ?? "n/a"
    NSLog(
        "[MacStyleRewriteLocal] style=%@ chunk=%d lora=%@ load=%@ inputTokens=%d outputTokens=%d prefill=%.3f decode=%.3f total=%.3f tokPerSecond=%@",
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

private func logMacLocalLoRAMissing(
    styleIdentifier: String,
    chunkIndex: Int,
    adapter: MacLocalRewriteAdapterKind
) {
    #if DEBUG
    NSLog(
        "[MacStyleRewriteLocal] style=%@ chunk=%d lora=%@ missing",
        styleIdentifier,
        chunkIndex,
        adapter.logLabel
    )
    #endif
}

private func logMacLocalPrewarm(
    styleIdentifier: String,
    adapterKind: MacLocalRewriteAdapterKind?,
    loadDuration: TimeInterval?
) {
    #if DEBUG
    let loadDurationText = loadDuration.map { String(format: "%.3f", $0) } ?? "cached"
    NSLog(
        "[MacStyleRewriteLocal] prewarm style=%@ lora=%@ load=%@",
        styleIdentifier,
        adapterKind?.logLabel ?? "none",
        loadDurationText
    )
    #endif
}

private func logMacLocalPrewarmFailure(
    styleIdentifier: String,
    adapterKind: MacLocalRewriteAdapterKind?,
    error: Error
) {
    #if DEBUG
    NSLog(
        "[MacStyleRewriteLocal] prewarm style=%@ lora=%@ error=%@",
        styleIdentifier,
        adapterKind?.logLabel ?? "none",
        String(describing: error)
    )
    #endif
}

private extension MacLocalRewriteAdapterKind {
    var logLabel: String {
        switch self {
        case .polished:
            return "polished-alpha-021"
        case .casual:
            return "casual-alpha-3"
        }
    }
}
