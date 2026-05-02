import Foundation

public struct TextTransformRequest: Codable, Equatable, Sendable {
    public let baseText: String
    public let styleIdentifier: String
    public let instructions: String
    public let promptPrefix: String
    public let promptSuffix: String
    public let contextTokenLimit: Int
    public let expectedOutputExpansionRatio: Double
    public let safetyMarginTokens: Int
    public let maximumResponseTokens: Int?

    public init(
        baseText: String,
        styleIdentifier: String,
        instructions: String,
        promptPrefix: String,
        promptSuffix: String = "",
        contextTokenLimit: Int,
        expectedOutputExpansionRatio: Double,
        safetyMarginTokens: Int,
        maximumResponseTokens: Int? = nil
    ) {
        self.baseText = baseText
        self.styleIdentifier = styleIdentifier
        self.instructions = instructions
        self.promptPrefix = promptPrefix
        self.promptSuffix = promptSuffix
        self.contextTokenLimit = contextTokenLimit
        self.expectedOutputExpansionRatio = expectedOutputExpansionRatio
        self.safetyMarginTokens = safetyMarginTokens
        self.maximumResponseTokens = maximumResponseTokens
    }

    public func prompt(for chunkText: String) -> String {
        promptPrefix + chunkText + promptSuffix
    }
}

public enum TextTransformErrorCode: String, Codable, Equatable, Sendable {
    case emptyResponse
    case foundationModelsUnavailable
    case foundationRefusal
    case foundationGuardrailViolation
    case foundationExceededContextWindow
    case foundationGenerationFailed
    case generationFailed
}

public struct TextTransformErrorSummary: Codable, Equatable, Sendable {
    public let chunkIndex: Int?
    public let message: String
    public let errorCode: TextTransformErrorCode?

    public init(
        chunkIndex: Int?,
        message: String,
        errorCode: TextTransformErrorCode? = nil
    ) {
        self.chunkIndex = chunkIndex
        self.message = message
        self.errorCode = errorCode
    }
}

public struct TextTransformChunkTiming: Codable, Equatable, Sendable {
    public let chunkIndex: Int
    public let inputTokenCount: Int
    public let duration: TimeInterval
    public let usedFallbackText: Bool

    public init(
        chunkIndex: Int,
        inputTokenCount: Int,
        duration: TimeInterval,
        usedFallbackText: Bool
    ) {
        self.chunkIndex = chunkIndex
        self.inputTokenCount = inputTokenCount
        self.duration = duration
        self.usedFallbackText = usedFallbackText
    }
}

public struct TextTransformResult: Codable, Equatable, Sendable {
    public let originalText: String
    public let finalText: String
    public let styleIdentifier: String
    public let duration: TimeInterval
    public let chunkCount: Int
    public let applied: Bool
    public let chunkTimings: [TextTransformChunkTiming]
    public let errors: [TextTransformErrorSummary]
    public let processingMode: String?

    public init(
        originalText: String,
        finalText: String,
        styleIdentifier: String,
        duration: TimeInterval,
        chunkCount: Int,
        applied: Bool,
        chunkTimings: [TextTransformChunkTiming],
        errors: [TextTransformErrorSummary],
        processingMode: String? = nil
    ) {
        self.originalText = originalText
        self.finalText = finalText
        self.styleIdentifier = styleIdentifier
        self.duration = duration
        self.chunkCount = chunkCount
        self.applied = applied
        self.chunkTimings = chunkTimings
        self.errors = errors
        self.processingMode = processingMode
    }

    public static func fallback(
        request: TextTransformRequest,
        duration: TimeInterval,
        errors: [TextTransformErrorSummary]
    ) -> TextTransformResult {
        TextTransformResult(
            originalText: request.baseText,
            finalText: request.baseText,
            styleIdentifier: request.styleIdentifier,
            duration: duration,
            chunkCount: request.baseText.isEmpty ? 0 : 1,
            applied: false,
            chunkTimings: [],
            errors: errors,
            processingMode: nil
        )
    }
}

public struct DictationTextVariantArtifact: Codable, Equatable, Sendable {
    public let styleIdentifier: String
    public let text: String
    public let duration: TimeInterval
    public let chunkCount: Int
    public let applied: Bool
    public let errors: [String]

    public init(
        styleIdentifier: String,
        text: String,
        duration: TimeInterval,
        chunkCount: Int,
        applied: Bool,
        errors: [String]
    ) {
        self.styleIdentifier = styleIdentifier
        self.text = text
        self.duration = duration
        self.chunkCount = chunkCount
        self.applied = applied
        self.errors = errors
    }
}

public struct DictationDeterministicTextVariantArtifact: Codable, Equatable, Sendable {
    public let paragraphsEnabled: Bool
    public let listsEnabled: Bool
    public let text: String

    public init(
        paragraphsEnabled: Bool,
        listsEnabled: Bool,
        text: String
    ) {
        self.paragraphsEnabled = paragraphsEnabled
        self.listsEnabled = listsEnabled
        self.text = text
    }
}

public struct DictationUtteranceArtifact: Codable, Equatable, Sendable {
    public let id: UUID
    public let rawText: String
    public let baseText: String
    public let selectedText: String
    public let selectedStyleIdentifier: String?
    public let variants: [DictationTextVariantArtifact]
    public let deterministicVariants: [DictationDeterministicTextVariantArtifact]
    public let inferenceDuration: TimeInterval
    public let textTransformationDuration: TimeInterval
    public let createdAt: Date

    public init(
        id: UUID,
        rawText: String,
        baseText: String,
        selectedText: String,
        selectedStyleIdentifier: String?,
        variants: [DictationTextVariantArtifact],
        deterministicVariants: [DictationDeterministicTextVariantArtifact] = [],
        inferenceDuration: TimeInterval,
        textTransformationDuration: TimeInterval,
        createdAt: Date
    ) {
        self.id = id
        self.rawText = rawText
        self.baseText = baseText
        self.selectedText = selectedText
        self.selectedStyleIdentifier = selectedStyleIdentifier
        self.variants = variants
        self.deterministicVariants = deterministicVariants
        self.inferenceDuration = inferenceDuration
        self.textTransformationDuration = textTransformationDuration
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case rawText
        case baseText
        case selectedText
        case selectedStyleIdentifier
        case variants
        case deterministicVariants
        case inferenceDuration
        case textTransformationDuration
        case createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        rawText = try container.decode(String.self, forKey: .rawText)
        baseText = try container.decode(String.self, forKey: .baseText)
        selectedText = try container.decode(String.self, forKey: .selectedText)
        selectedStyleIdentifier = try container.decodeIfPresent(String.self, forKey: .selectedStyleIdentifier)
        variants = try container.decode([DictationTextVariantArtifact].self, forKey: .variants)
        deterministicVariants = try container.decodeIfPresent(
            [DictationDeterministicTextVariantArtifact].self,
            forKey: .deterministicVariants
        ) ?? []
        inferenceDuration = try container.decode(TimeInterval.self, forKey: .inferenceDuration)
        textTransformationDuration = try container.decode(TimeInterval.self, forKey: .textTransformationDuration)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

@MainActor
public protocol DictationTextTransforming: AnyObject {
    func prewarm(request: TextTransformRequest)
    func transform(_ request: TextTransformRequest) async -> TextTransformResult
}
