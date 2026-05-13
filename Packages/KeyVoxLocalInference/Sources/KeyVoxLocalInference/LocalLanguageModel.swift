import Foundation

public struct LocalLanguageModelConfiguration: Equatable, Sendable {
    public let contextTokenLimit: Int
    public let threadCount: Int
    public let batchThreadCount: Int
    public let batchTokenCount: Int

    public init(
        contextTokenLimit: Int,
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
    public let reachedMaximumTokenCount: Bool
    public let prefillDuration: TimeInterval
    public let decodeDuration: TimeInterval
    public let totalDuration: TimeInterval

    public init(
        loadDuration: TimeInterval?,
        inputTokenCount: Int,
        outputTokenCount: Int,
        reachedMaximumTokenCount: Bool = false,
        prefillDuration: TimeInterval,
        decodeDuration: TimeInterval,
        totalDuration: TimeInterval
    ) {
        self.loadDuration = loadDuration
        self.inputTokenCount = inputTokenCount
        self.outputTokenCount = outputTokenCount
        self.reachedMaximumTokenCount = reachedMaximumTokenCount
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
    case outputTruncated(maximumTokenCount: Int)
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
        case let .outputTruncated(maximumTokenCount):
            return "outputTruncated(maximumTokenCount=\(maximumTokenCount))"
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
