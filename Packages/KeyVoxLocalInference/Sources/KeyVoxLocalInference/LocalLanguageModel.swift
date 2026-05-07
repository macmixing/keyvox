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

public enum LocalLanguageModelError: Error, Equatable, Sendable, CustomStringConvertible {
    case modelFileMissing
    case modelLoadFailed
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
    func generate(
        _ request: LocalLanguageModelGenerationRequest,
        configuration: LocalLanguageModelConfiguration
    ) async throws -> LocalLanguageModelGenerationResult

    func unload() async
}

public final class LlamaCPULanguageModel: LocalLanguageModelGenerating, @unchecked Sendable {
    private let modelURL: URL
    private let fileManager: FileManager
    private let inferenceQueue: DispatchQueue
    private var loadedModel: LlamaLoadedModel?

    public init(
        modelURL: URL,
        fileManager: FileManager = .default,
        inferenceQueue: DispatchQueue = DispatchQueue(label: "com.cueit.keyvox.local-inference.llama-cpu")
    ) {
        self.modelURL = modelURL
        self.fileManager = fileManager
        self.inferenceQueue = inferenceQueue
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

    public func unload() async {
        await withCheckedContinuation { continuation in
            inferenceQueue.async { [self] in
                loadedModel = nil
                continuation.resume()
            }
        }
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
        if let loadedModel {
            return loadedModel
        }

        guard fileManager.fileExists(atPath: modelURL.path) else {
            throw LocalLanguageModelError.modelFileMissing
        }

        let start = Date()
        var modelParameters = llama_model_default_params()
        modelParameters.n_gpu_layers = 0
        modelParameters.use_mmap = true
        modelParameters.use_mlock = false
        modelParameters.check_tensors = true
        modelParameters.use_extra_bufts = false
        modelParameters.no_host = false

        var devices: [ggml_backend_dev_t?] = [nil]
        let model = devices.withUnsafeMutableBufferPointer { devicesBuffer in
            modelParameters.devices = devicesBuffer.baseAddress
            return modelURL.path.withCString { llama_model_load_from_file($0, modelParameters) }
        }

        guard let model else {
            throw LocalLanguageModelError.modelLoadFailed
        }

        var contextParameters = llama_context_default_params()
        contextParameters.n_ctx = UInt32(max(configuration.contextTokenLimit, 1))
        contextParameters.n_batch = UInt32(max(configuration.batchTokenCount, 1))
        contextParameters.n_ubatch = UInt32(max(configuration.batchTokenCount, 1))
        contextParameters.n_threads = Int32(max(configuration.threadCount, 1))
        contextParameters.n_threads_batch = Int32(max(configuration.batchThreadCount, 1))
        contextParameters.offload_kqv = false
        contextParameters.op_offload = false
        contextParameters.embeddings = false

        guard let context = llama_init_from_model(model, contextParameters) else {
            llama_model_free(model)
            throw LocalLanguageModelError.contextCreateFailed
        }

        let loaded = LlamaLoadedModel(
            model: model,
            context: context,
            vocab: llama_model_get_vocab(model),
            lastLoadDuration: Date().timeIntervalSince(start)
        )
        loadedModel = loaded
        return loaded
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
    var lastLoadDuration: TimeInterval?

    init(
        model: OpaquePointer,
        context: OpaquePointer,
        vocab: OpaquePointer,
        lastLoadDuration: TimeInterval?
    ) {
        self.model = model
        self.context = context
        self.vocab = vocab
        self.lastLoadDuration = lastLoadDuration
    }

    deinit {
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
