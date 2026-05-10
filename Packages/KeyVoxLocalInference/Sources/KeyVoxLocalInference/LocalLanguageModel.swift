import Foundation
@preconcurrency import llama

public struct LocalLanguageModelConfiguration: Equatable, Sendable {
    public let contextTokenLimit: Int
    public let threadCount: Int
    public let batchThreadCount: Int
    public let batchTokenCount: Int

    public init(
        contextTokenLimit: Int = 4_096,
        threadCount: Int = 2,
        batchThreadCount: Int = 2,
        batchTokenCount: Int = 512
    ) {
        self.contextTokenLimit = contextTokenLimit
        self.threadCount = threadCount
        self.batchThreadCount = batchThreadCount
        self.batchTokenCount = batchTokenCount
    }
}

public enum LocalLanguageModelGPUOffloadMode: Equatable, Sendable {
    case disabled
    case automatic
    case allLayers
    case layerCount(Int32)
}

public struct LocalLanguageModelGenerationRequest: Equatable, Sendable {
    public let prompt: String
    public let systemPrompt: String?
    public let userPrompt: String?
    public let maximumTokenCount: Int
    public let usesChatTemplate: Bool
    public let addsSpecialTokens: Bool

    public init(
        prompt: String,
        maximumTokenCount: Int,
        usesChatTemplate: Bool = true,
        addsSpecialTokens: Bool = true
    ) {
        self.prompt = prompt
        self.systemPrompt = nil
        self.userPrompt = nil
        self.maximumTokenCount = maximumTokenCount
        self.usesChatTemplate = usesChatTemplate
        self.addsSpecialTokens = addsSpecialTokens
    }

    public init(
        systemPrompt: String,
        userPrompt: String,
        maximumTokenCount: Int,
        usesChatTemplate: Bool = true,
        addsSpecialTokens: Bool = true
    ) {
        self.prompt = userPrompt
        self.systemPrompt = systemPrompt
        self.userPrompt = userPrompt
        self.maximumTokenCount = maximumTokenCount
        self.usesChatTemplate = usesChatTemplate
        self.addsSpecialTokens = addsSpecialTokens
    }
}

public struct LocalLanguageModelGenerationMetrics: Equatable, Sendable {
    public let loadDuration: TimeInterval?
    public let inputTokenCount: Int
    public let outputTokenCount: Int
    public let prefillDuration: TimeInterval
    public let decodeDuration: TimeInterval
    public let totalDuration: TimeInterval

    public init(
        loadDuration: TimeInterval?,
        inputTokenCount: Int,
        outputTokenCount: Int,
        prefillDuration: TimeInterval,
        decodeDuration: TimeInterval,
        totalDuration: TimeInterval
    ) {
        self.loadDuration = loadDuration
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.prefillDuration = prefillDuration
        self.decodeDuration = decodeDuration
        self.totalDuration = totalDuration
    }

    public var decodeTokensPerSecond: Double? {
        guard decodeDuration > 0 else { return nil }
        return Double(outputTokenCount) / decodeDuration
    }
}

public struct LocalLanguageModelGenerationResult: Equatable, Sendable {
    public let text: String
    public let metrics: LocalLanguageModelGenerationMetrics

    public init(text: String, metrics: LocalLanguageModelGenerationMetrics) {
        self.text = text
        self.metrics = metrics
    }
}

public struct LocalLanguageModelPreparationResult: Equatable, Sendable {
    public let loadDuration: TimeInterval?

    public init(loadDuration: TimeInterval?) {
        self.loadDuration = loadDuration
    }
}

public enum LocalLanguageModelError: Error, Equatable, Sendable, CustomStringConvertible {
    case modelFileMissing
    case modelLoadFailed
    case adapterFileMissing
    case adapterLoadFailed
    case adapterAttachFailed(code: Int32)
    case contextCreateFailed
    case tokenizerFailed
    case promptTooLong(inputTokenCount: Int, contextTokenLimit: Int)
    case decodeFailed(code: Int32)
    case emptyOutput
    case cancelled

    public var description: String {
        switch self {
        case .modelFileMissing:
            return "modelFileMissing"
        case .modelLoadFailed:
            return "modelLoadFailed"
        case .adapterFileMissing:
            return "adapterFileMissing"
        case .adapterLoadFailed:
            return "adapterLoadFailed"
        case let .adapterAttachFailed(code):
            return "adapterAttachFailed(code=\(code))"
        case .contextCreateFailed:
            return "contextCreateFailed"
        case .tokenizerFailed:
            return "tokenizerFailed"
        case let .promptTooLong(inputTokenCount, contextTokenLimit):
            return "promptTooLong(inputTokenCount=\(inputTokenCount), contextTokenLimit=\(contextTokenLimit))"
        case let .decodeFailed(code):
            return "decodeFailed(code=\(code))"
        case .emptyOutput:
            return "emptyOutput"
        case .cancelled:
            return "cancelled"
        }
    }
}

public protocol LocalLanguageModelGenerating: Sendable {
    func prepare(configuration: LocalLanguageModelConfiguration) async throws -> LocalLanguageModelPreparationResult

    func generate(
        _ request: LocalLanguageModelGenerationRequest,
        configuration: LocalLanguageModelConfiguration
    ) async throws -> LocalLanguageModelGenerationResult

    func unload() async
}

public final class LlamaCPULanguageModel: LocalLanguageModelGenerating, @unchecked Sendable {
    public typealias DiagnosticLogHandler = @Sendable (String) -> Void

    private static let initializeLlamaRuntime: Void = {
        llama_log_set({ _, _, _ in }, nil)
        ggml_backend_load_all()
        llama_backend_init()
    }()

    private let modelURL: URL
    public let adapterURL: URL?
    private let fileManager: FileManager
    private let inferenceQueue: DispatchQueue
    private let adapterScale: Float
    private let gpuOffloadMode: LocalLanguageModelGPUOffloadMode
    private let diagnosticLog: DiagnosticLogHandler
    private var loadedModel: LlamaLoadedModel?

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
        configuration: LocalLanguageModelConfiguration = LocalLanguageModelConfiguration()
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
        configuration: LocalLanguageModelConfiguration = LocalLanguageModelConfiguration()
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

    private func prepareSynchronously(
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

    private func generateSynchronously(
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

        return LocalLanguageModelGenerationResult(
            text: trimmedText,
            metrics: LocalLanguageModelGenerationMetrics(
                loadDuration: loadDuration,
                inputTokenCount: promptTokens.count,
                outputTokenCount: outputTokenCount,
                prefillDuration: prefillDuration,
                decodeDuration: decodeDuration,
                totalDuration: totalDuration
            )
        )
    }

    private func loadModelIfNeeded(configuration: LocalLanguageModelConfiguration) throws -> LlamaLoadedModel {
        _ = Self.initializeLlamaRuntime

        if let loadedModel {
            return loadedModel
        }

        guard fileManager.fileExists(atPath: modelURL.path) else {
            throw LocalLanguageModelError.modelFileMissing
        }

        let loaded = try loadModelWithFallbackIfNeeded(configuration: configuration)
        loadedModel = loaded
        return loaded
    }

    private func loadModelWithFallbackIfNeeded(configuration: LocalLanguageModelConfiguration) throws -> LlamaLoadedModel {
        let gpuSupport = Self.supportsGPUOffloadForCurrentPlatform()
        let requestedGPULayers = requestedGPULayerCount(gpuSupport: gpuSupport)
        let deviceSummary = Self.backendDeviceSummaryForDiagnostics()

        if let requestedGPULayers {
            diagnosticLog(
                "gpu-offload mode=\(gpuOffloadMode.logLabel) supported=\(gpuSupport) action=attempt layers=\(requestedGPULayers) devices=\(deviceSummary)"
            )

            do {
                let loaded = try loadModel(
                    configuration: configuration,
                    gpuLayerCount: requestedGPULayers
                )
                diagnosticLog(
                    "gpu-offload mode=\(gpuOffloadMode.logLabel) backend=gpu layers=\(requestedGPULayers)"
                )
                return loaded
            } catch LocalLanguageModelError.modelLoadFailed {
                diagnosticLog(
                    "gpu-offload mode=\(gpuOffloadMode.logLabel) fallback=cpu reason=modelLoadFailed"
                )
            } catch LocalLanguageModelError.contextCreateFailed {
                diagnosticLog(
                    "gpu-offload mode=\(gpuOffloadMode.logLabel) fallback=cpu reason=contextCreateFailed"
                )
            }
        } else if gpuOffloadMode != .disabled {
            diagnosticLog(
                "gpu-offload mode=\(gpuOffloadMode.logLabel) supported=\(gpuSupport) action=cpu devices=\(deviceSummary)"
            )
        }

        let loaded = try loadModel(configuration: configuration, gpuLayerCount: 0)
        diagnosticLog("gpu-offload mode=\(gpuOffloadMode.logLabel) backend=cpu layers=0")
        return loaded
    }

    private func loadModel(
        configuration: LocalLanguageModelConfiguration,
        gpuLayerCount: Int32
    ) throws -> LlamaLoadedModel {
        let start = Date()
        var modelParameters = llama_model_default_params()
        modelParameters.n_gpu_layers = gpuLayerCount
        modelParameters.use_mmap = true
        modelParameters.use_mlock = false
        modelParameters.check_tensors = true
        modelParameters.use_extra_bufts = false
        modelParameters.no_host = false

        let model = modelURL.path.withCString { llama_model_load_from_file($0, modelParameters) }

        guard let model else {
            throw LocalLanguageModelError.modelLoadFailed
        }

        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = UInt32(max(configuration.contextTokenLimit, 1))
        contextParameters.n_batch = UInt32(max(configuration.batchTokenCount, 1))
        contextParameters.n_ubatch = UInt32(max(configuration.batchTokenCount, 1))
        contextParameters.n_threads = Int32(max(configuration.threadCount, 1))
        contextParameters.n_threads_batch = Int32(max(configuration.batchThreadCount, 1))
        contextParameters.offload_kqv = gpuLayerCount != 0
        contextParameters.op_offload = gpuLayerCount != 0
        contextParameters.embeddings = false

        guard let context = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            throw LocalLanguageModelError.contextCreateFailed
        }

        let adapter = try loadAdapterIfNeeded(model: model, context: context)

        return LlamaLoadedModel(
            model: model,
            context: context,
            vocab: llama_model_get_vocab(model),
            adapter: adapter,
            lastLoadDuration: Date().timeIntervalSince(start)
        )
    }

    private func requestedGPULayerCount(gpuSupport: Bool) -> Int32? {
        guard gpuSupport else { return nil }

        #if os(macOS)
        switch gpuOffloadMode {
        case .disabled:
            return nil
        case .automatic, .allLayers:
            return -1
        case .layerCount(let layerCount):
            return max(layerCount, 0)
        }
        #else
        return nil
        #endif
    }

    private static func supportsGPUOffloadForCurrentPlatform() -> Bool {
        #if os(macOS)
        _ = Self.initializeLlamaRuntime
        return llama_supports_gpu_offload()
        #else
        return false
        #endif
    }

    private static func backendDeviceSummaryForDiagnostics() -> String {
        #if os(macOS)
        _ = Self.initializeLlamaRuntime
        let deviceCount = ggml_backend_dev_count()
        guard deviceCount > 0 else {
            return "count=0"
        }

        var entries: [String] = []
        for index in 0..<deviceCount {
            guard let device = ggml_backend_dev_get(index) else {
                entries.append("\(index):missing")
                continue
            }

            let name = ggml_backend_dev_name(device).map { String(cString: $0) } ?? "unknown"
            let description = ggml_backend_dev_description(device).map { String(cString: $0) } ?? "unknown"
            entries.append("\(index):\(name):\(description)")
        }
        return "count=\(deviceCount) [\(entries.joined(separator: ","))]"
        #else
        return "unavailable"
        #endif
    }

    private func loadAdapterIfNeeded(model: OpaquePointer, context: OpaquePointer) throws -> OpaquePointer? {
        guard let adapterURL else {
            return nil
        }

        guard fileManager.fileExists(atPath: adapterURL.path) else {
            llama_free(context)
            llama_model_free(model)
            throw LocalLanguageModelError.adapterFileMissing
        }

        let adapter = adapterURL.path.withCString { path in
            llama_adapter_lora_init(model, path)
        }

        guard let adapter else {
            llama_free(context)
            llama_model_free(model)
            throw LocalLanguageModelError.adapterLoadFailed
        }

        var adapters: [OpaquePointer?] = [adapter]
        var scales: [Float] = [adapterScale]
        let status = adapters.withUnsafeMutableBufferPointer { adapterBuffer in
            scales.withUnsafeMutableBufferPointer { scaleBuffer in
                llama_set_adapters_lora(
                    context,
                    adapterBuffer.baseAddress,
                    adapterBuffer.count,
                    scaleBuffer.baseAddress
                )
            }
        }

        guard status == 0 else {
            llama_adapter_lora_free(adapter)
            llama_free(context)
            llama_model_free(model)
            throw LocalLanguageModelError.adapterAttachFailed(code: status)
        }

        return adapter
    }

    private func formattedPrompt(
        for request: LocalLanguageModelGenerationRequest,
        loadedModel: LlamaLoadedModel
    ) throws -> String {
        guard request.usesChatTemplate else {
            return request.prompt
        }

        if let systemPrompt = request.systemPrompt, let userPrompt = request.userPrompt {
            return try chatPrompt(systemPrompt: systemPrompt, userPrompt: userPrompt, loadedModel: loadedModel)
        }

        return try chatPrompt(userPrompt: request.prompt, loadedModel: loadedModel)
    }

    private func chatPrompt(userPrompt: String, loadedModel: LlamaLoadedModel) throws -> String {
        try chatPrompt(messages: [("user", userPrompt)], loadedModel: loadedModel)
    }

    private func chatPrompt(
        systemPrompt: String,
        userPrompt: String,
        loadedModel: LlamaLoadedModel
    ) throws -> String {
        try chatPrompt(
            messages: [
                ("system", systemPrompt),
                ("user", userPrompt)
            ],
            loadedModel: loadedModel
        )
    }

    private func chatPrompt(
        messages: [(role: String, content: String)],
        loadedModel: LlamaLoadedModel
    ) throws -> String {
        let template = llama_model_chat_template(loadedModel.model, nil)
        let requiredLength = try withChatMessages(messages) { chatMessages in
            var mutableMessages = chatMessages
            return llama_chat_apply_template(template, &mutableMessages, mutableMessages.count, true, nil, 0)
        }

        guard requiredLength >= 0 else {
            throw LocalLanguageModelError.tokenizerFailed
        }

        var buffer = [CChar](repeating: 0, count: Int(requiredLength) + 1)
        let writtenLength = try withChatMessages(messages) { chatMessages in
            var mutableMessages = chatMessages
            return llama_chat_apply_template(template, &mutableMessages, mutableMessages.count, true, &buffer, Int32(buffer.count))
        }

        guard writtenLength >= 0 else {
            throw LocalLanguageModelError.tokenizerFailed
        }

        return String(decoding: buffer.prefix(Int(writtenLength)).map(UInt8.init(bitPattern:)), as: UTF8.self)
    }

    private func withChatMessages<T>(
        _ messages: [(role: String, content: String)],
        _ body: ([llama_chat_message]) throws -> T
    ) throws -> T {
        var chatMessages: [llama_chat_message] = []
        chatMessages.reserveCapacity(messages.count)

        func appendMessage(at index: Int) throws -> T {
            guard index < messages.count else {
                return try body(chatMessages)
            }

            return try messages[index].role.withCString { rolePointer in
                try messages[index].content.withCString { contentPointer in
                    chatMessages.append(llama_chat_message(role: rolePointer, content: contentPointer))
                    defer { _ = chatMessages.popLast() }
                    return try appendMessage(at: index + 1)
                }
            }
        }

        return try appendMessage(at: 0)
    }

    private func tokenize(
        _ text: String,
        loadedModel: LlamaLoadedModel,
        addSpecial: Bool,
        parseSpecial: Bool
    ) throws -> [llama_token] {
        let tokenCapacity = text.utf8.count + 8
        var tokens = [llama_token](repeating: 0, count: max(tokenCapacity, 1))

        let tokenCount = text.withCString { cString in
            llama_tokenize(
                loadedModel.vocab,
                cString,
                Int32(strlen(cString)),
                &tokens,
                Int32(tokens.count),
                addSpecial,
                parseSpecial
            )
        }

        if tokenCount < 0 {
            tokens = [llama_token](repeating: 0, count: Int(-tokenCount))
            let retryCount = text.withCString { cString in
                llama_tokenize(
                    loadedModel.vocab,
                    cString,
                    Int32(strlen(cString)),
                    &tokens,
                    Int32(tokens.count),
                    addSpecial,
                    parseSpecial
                )
            }
            guard retryCount >= 0 else {
                throw LocalLanguageModelError.tokenizerFailed
            }
            return Array(tokens.prefix(Int(retryCount)))
        }

        return Array(tokens.prefix(Int(tokenCount)))
    }

    private func decode(
        tokens: [llama_token],
        startingAt startPosition: Int32,
        context: OpaquePointer,
        needsLogits: Bool
    ) throws -> Int32 {
        guard !tokens.isEmpty else { return startPosition }

        var batch = llama_batch_init(Int32(tokens.count), 0, 1)
        defer {
            llama_batch_free(batch)
        }

        batch.n_tokens = Int32(tokens.count)
        for (index, token) in tokens.enumerated() {
            batch.token[index] = token
            batch.pos[index] = startPosition + Int32(index)
            batch.n_seq_id[index] = 1
            batch.seq_id[index]?[0] = 0
            batch.logits[index] = 0
        }
        if needsLogits {
            batch.logits[tokens.count - 1] = 1
        }

        let status = llama_decode(context, batch)
        guard status == 0 else {
            throw LocalLanguageModelError.decodeFailed(code: status)
        }
        return startPosition + Int32(tokens.count)
    }

    private func decodePrefill(tokens: [llama_token], context: OpaquePointer) throws -> Int32 {
        guard !tokens.isEmpty else { return 0 }

        let batchLimit = max(1, Int(llama_n_batch(context)))
        var currentPosition: Int32 = 0
        var startIndex = tokens.startIndex

        while startIndex < tokens.endIndex {
            let remainingCount = tokens.distance(from: startIndex, to: tokens.endIndex)
            let chunkCount = min(batchLimit, remainingCount)
            let endIndex = tokens.index(startIndex, offsetBy: chunkCount)
            let isFinalChunk = endIndex == tokens.endIndex
            currentPosition = try decode(
                tokens: Array(tokens[startIndex..<endIndex]),
                startingAt: currentPosition,
                context: context,
                needsLogits: isFinalChunk
            )
            startIndex = endIndex
        }

        return currentPosition
    }

    private func tokenText(_ token: llama_token, vocab: OpaquePointer) -> String {
        var buffer = [CChar](repeating: 0, count: 128)
        let count = llama_token_to_piece(
            vocab,
            token,
            &buffer,
            Int32(buffer.count),
            0,
            false
        )

        if count < 0 {
            buffer = [CChar](repeating: 0, count: Int(-count))
            let retryCount = llama_token_to_piece(
                vocab,
                token,
                &buffer,
                Int32(buffer.count),
                0,
                false
            )
            guard retryCount > 0 else { return "" }
            return String(decoding: buffer.prefix(Int(retryCount)).map(UInt8.init(bitPattern:)), as: UTF8.self)
        }

        guard count > 0 else { return "" }
        return String(decoding: buffer.prefix(Int(count)).map(UInt8.init(bitPattern:)), as: UTF8.self)
    }
}

private final class LlamaLoadedModel {
    let model: OpaquePointer
    let context: OpaquePointer
    let vocab: OpaquePointer
    let adapter: OpaquePointer?
    var lastLoadDuration: TimeInterval?

    init(
        model: OpaquePointer,
        context: OpaquePointer,
        vocab: OpaquePointer,
        adapter: OpaquePointer?,
        lastLoadDuration: TimeInterval?
    ) {
        self.model = model
        self.context = context
        self.vocab = vocab
        self.adapter = adapter
        self.lastLoadDuration = lastLoadDuration
    }

    deinit {
        if let adapter {
            llama_set_adapters_lora(context, nil, 0, nil)
            llama_adapter_lora_free(adapter)
        }
        llama_free(context)
        llama_model_free(model)
    }
}

final class LocalInferenceCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false

    func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    func checkCancellation() throws {
        lock.lock()
        let currentValue = isCancelled
        lock.unlock()

        if currentValue {
            throw LocalLanguageModelError.cancelled
        }
    }
}

private extension LocalLanguageModelGPUOffloadMode {
    var logLabel: String {
        switch self {
        case .disabled:
            return "disabled"
        case .automatic:
            return "automatic"
        case .allLayers:
            return "allLayers"
        case .layerCount(let layerCount):
            return "layerCount(\(layerCount))"
        }
    }
}
