import Foundation
@preconcurrency import llama

public final class LlamaLocalLanguageModel: LocalLanguageModelGenerating, @unchecked Sendable {
    public typealias DiagnosticLogHandler = @Sendable (String) -> Void

    static let initializeCoreRuntime: Void = {
        llama_log_set({ _, _, _ in }, nil)
        llama_backend_init()
    }()

    static let initializeGPUBackends: Void = {
        _ = initializeCoreRuntime
        ggml_backend_load_all()
    }()

    let modelURL: URL
    public let adapterURL: URL?
    let fileManager: FileManager
    let inferenceQueue: DispatchQueue
    let adapterScale: Float
    let gpuOffloadMode: LocalLanguageModelGPUOffloadMode
    let diagnosticLog: DiagnosticLogHandler
    var loadedModel: LlamaLoadedModel?

    private static let defaultDiagnosticLog: DiagnosticLogHandler = { message in
        #if DEBUG
        NSLog("[KeyVoxLocalInference] %@", message)
        #else
        _ = message
        #endif
    }

    public var hasLoRAAdapter: Bool {
        adapterURL != nil
    }

    public init(
        modelURL: URL,
        adapterURL: URL? = nil,
        adapterScale: Float = 1.0,
        gpuOffloadMode: LocalLanguageModelGPUOffloadMode = .disabled,
        fileManager: FileManager = .default,
        inferenceQueue: DispatchQueue = DispatchQueue(label: "com.cueit.keyvox.local-inference.llama-cpu"),
        diagnosticLog: DiagnosticLogHandler? = nil
    ) {
        self.modelURL = modelURL
        self.adapterURL = adapterURL
        self.adapterScale = adapterScale
        self.gpuOffloadMode = gpuOffloadMode
        self.fileManager = fileManager
        self.inferenceQueue = inferenceQueue
        self.diagnosticLog = diagnosticLog ?? Self.defaultDiagnosticLog
    }

    public func generate(
        _ request: LocalLanguageModelGenerationRequest,
        configuration: LocalLanguageModelConfiguration
    ) async throws -> LocalLanguageModelGenerationResult {
        let cancellation = LocalInferenceCancellationToken()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                inferenceQueue.async { [self] in
                    do {
                        let result = try generateSynchronously(
                            request,
                            configuration: configuration,
                            cancellation: cancellation
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

    public func prepare(
        configuration: LocalLanguageModelConfiguration
    ) async throws -> LocalLanguageModelPreparationResult {
        try await withCheckedThrowingContinuation { continuation in
            inferenceQueue.async { [self] in
                do {
                    let result = try prepareSynchronously(configuration: configuration)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    public func unload() async {
        await withCheckedContinuation { continuation in
            inferenceQueue.async { [self] in
                loadedModel = nil
                continuation.resume()
            }
        }
    }

    func prepareSynchronously(
        configuration: LocalLanguageModelConfiguration
    ) throws -> LocalLanguageModelPreparationResult {
        let loaded = try loadModelIfNeeded(configuration: configuration)
        let loadDuration = loaded.lastLoadDuration
        loaded.lastLoadDuration = nil
        llama_set_n_threads(
            loaded.context,
            Int32(max(configuration.threadCount, 1)),
            Int32(max(configuration.batchThreadCount, 1))
        )
        llama_memory_clear(llama_get_memory(loaded.context), true)
        return LocalLanguageModelPreparationResult(loadDuration: loadDuration)
    }

    func generateSynchronously(
        _ request: LocalLanguageModelGenerationRequest,
        configuration: LocalLanguageModelConfiguration,
        cancellation: LocalInferenceCancellationToken
    ) throws -> LocalLanguageModelGenerationResult {
        try cancellation.checkCancellation()

        let totalStart = Date()
        let loaded = try loadModelIfNeeded(configuration: configuration)
        let loadDuration = loaded.lastLoadDuration
        loaded.lastLoadDuration = nil
        llama_set_n_threads(
            loaded.context,
            Int32(max(configuration.threadCount, 1)),
            Int32(max(configuration.batchThreadCount, 1))
        )
        llama_memory_clear(llama_get_memory(loaded.context), true)

        let prompt = try formattedPrompt(for: request, loadedModel: loaded)
        let promptTokens = try tokenize(
            prompt,
            loadedModel: loaded,
            addSpecial: request.addsSpecialTokens,
            parseSpecial: true
        )

        guard promptTokens.count < configuration.contextTokenLimit else {
            throw LocalLanguageModelError.promptTooLong(
                inputTokenCount: promptTokens.count,
                contextTokenLimit: configuration.contextTokenLimit
            )
        }

        let prefillStart = Date()
        var currentPosition = try decodePrefill(tokens: promptTokens, context: loaded.context)
        let prefillDuration = Date().timeIntervalSince(prefillStart)

        let sampler = llama_sampler_init_greedy()
        defer {
            if let sampler {
                llama_sampler_free(sampler)
            }
        }

        guard let sampler else {
            throw LocalLanguageModelError.contextCreateFailed
        }

        var generatedText = ""
        var outputTokenCount = 0
        let decodeStart = Date()

        for _ in 0..<max(request.maximumTokenCount, 1) {
            try cancellation.checkCancellation()

            let token = llama_sampler_sample(sampler, loaded.context, -1)
            if llama_vocab_is_eog(loaded.vocab, token) {
                break
            }

            llama_sampler_accept(sampler, token)
            generatedText += tokenText(token, vocab: loaded.vocab)
            outputTokenCount += 1
            currentPosition = try decode(tokens: [token], startingAt: currentPosition, context: loaded.context, needsLogits: true)
        }

        let decodeDuration = Date().timeIntervalSince(decodeStart)
        let totalDuration = Date().timeIntervalSince(totalStart)
        let trimmedText = generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw LocalLanguageModelError.emptyOutput
        }
        guard outputTokenCount < max(request.maximumTokenCount, 1) else {
            throw LocalLanguageModelError.outputTruncated(maximumTokenCount: max(request.maximumTokenCount, 1))
        }

        return LocalLanguageModelGenerationResult(
            text: trimmedText,
            metrics: LocalLanguageModelGenerationMetrics(
                loadDuration: loadDuration,
                inputTokenCount: promptTokens.count,
                outputTokenCount: outputTokenCount,
                reachedMaximumTokenCount: false,
                prefillDuration: prefillDuration,
                decodeDuration: decodeDuration,
                totalDuration: totalDuration
            )
        )
    }
}
