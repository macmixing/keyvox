import Foundation
import KeyVoxLocalInference
import KeyVoxStyleRewrite

@MainActor
final class LocalStyleRewriteTextTransformer: DictationTextTransforming {
    private let inferenceService: LocalRewriteInferenceService
    private var prewarmTask: Task<Void, Never>?
    private lazy var transformer = StyleRewriteTextTransformer { [weak self] _ in
        LocalStyleRewriteChunkResponder(
            inferenceService: self?.inferenceService,
            onModelOutput: { [weak self] request, output in
                self?.recordModelOutput(output, request: request)
            }
        )
    }
    private var modelOutputsBySignature: [String: [String]] = [:]

    init(inferenceService: LocalRewriteInferenceService) {
        self.inferenceService = inferenceService
    }

    func prewarm(request: TextTransformRequest) {
        prewarmTask?.cancel()
        let adapterKind = localRewriteAdapterKind(for: request.styleIdentifier)
        prewarmTask = Task { @MainActor [inferenceService] in
            do {
                guard !Task.isCancelled else { return }
                let model = try inferenceService.model(adapter: adapterKind)
                let result = try await model.prepare(
                    configuration: LocalLanguageModelConfiguration(
                        contextTokenLimit: request.contextTokenLimit,
                        threadCount: 2,
                        batchThreadCount: 2,
                        batchTokenCount: min(max(request.contextTokenLimit, 1), 512)
                    )
                )
                guard !Task.isCancelled else { return }
                logPrewarm(
                    styleIdentifier: request.styleIdentifier,
                    adapterKind: adapterKind,
                    loadDuration: result.loadDuration
                )
            } catch {
                logPrewarmFailure(
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

    func consumeModelOutput(styleIdentifier: String, sourceText: String) -> String? {
        let signature = modelOutputSignature(styleIdentifier: styleIdentifier, sourceText: sourceText)
        guard let outputs = modelOutputsBySignature.removeValue(forKey: signature),
              outputs.isEmpty == false else {
            return nil
        }

        return outputs.joined(separator: "\n")
    }

    func releaseResources(reason _: String) async {
        prewarmTask?.cancel()
        prewarmTask = nil
        await inferenceService.unload()
    }

    private func recordModelOutput(_ output: String, request: TextTransformRequest) {
        let signature = modelOutputSignature(
            styleIdentifier: request.styleIdentifier,
            sourceText: request.baseText
        )
        modelOutputsBySignature[signature, default: []].append(output)
    }

    private func modelOutputSignature(styleIdentifier: String, sourceText: String) -> String {
        "\(styleIdentifier)\u{1F}\(sourceText)"
    }
}

@MainActor
private final class LocalStyleRewriteChunkResponder: TextTransformChunkResponding {
    private let inferenceService: LocalRewriteInferenceService?
    private let onModelOutput: (TextTransformRequest, String) -> Void

    init(
        inferenceService: LocalRewriteInferenceService?,
        onModelOutput: @escaping (TextTransformRequest, String) -> Void
    ) {
        self.inferenceService = inferenceService
        self.onModelOutput = onModelOutput
    }

    func transformChunk(_ chunk: TextTransformChunk, request: TextTransformRequest) async throws -> String {
        guard let inferenceService else {
            throw StyleRewriteBackendError.modelNotInstalled
        }

        let adapterKind = localRewriteAdapterKind(for: request.styleIdentifier)
        let model: LlamaLocalLanguageModel
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
            onModelOutput(request, result.text)
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
        case .outputTruncated:
            return .outputTruncated(error.description)
        case .tokenizerFailed, .decodeFailed, .emptyOutput:
            return .generationFailed(error.description)
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

private func localRewriteAdapterKind(for styleIdentifier: String) -> LocalRewriteAdapterKind? {
    switch styleIdentifier {
    case StyleRewriteStyle.polished.styleIdentifier:
        return .polished
    case StyleRewriteStyle.casual.styleIdentifier, StyleRewriteStyle.chill.styleIdentifier:
        return .casual
    default:
        return nil
    }
}

private func logPrewarm(
    styleIdentifier: String,
    adapterKind: LocalRewriteAdapterKind?,
    loadDuration: TimeInterval?
) {
    #if DEBUG
    let loadDurationText = loadDuration.map { String(format: "%.3f", $0) } ?? "cached"
    NSLog(
        "[StyleRewriteLocal] prewarm style=%@ lora=%@ load=%@",
        styleIdentifier,
        adapterKind?.logLabel ?? "none",
        loadDurationText
    )
    #endif
}

private func logPrewarmFailure(
    styleIdentifier: String,
    adapterKind: LocalRewriteAdapterKind?,
    error: Error
) {
    #if DEBUG
    NSLog(
        "[StyleRewriteLocal] prewarm style=%@ lora=%@ error=%@",
        styleIdentifier,
        adapterKind?.logLabel ?? "none",
        String(describing: error)
    )
    #endif
}

private extension LocalRewriteAdapterKind {
    var logLabel: String {
        switch self {
        case .polished:
            return "polished-alpha-026"
        case .casual:
            return "casual-alpha-9"
        }
    }
}
