import Foundation

public enum StyleRewriteDictationModel: String, CaseIterable, Identifiable, Codable, Sendable {
    case whisper
    case parakeet

    public var id: String { rawValue }
}

public enum StyleRewriteStyle: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case casual
    case polished
    case chill

    public var id: String { rawValue }

    public var styleIdentifier: String {
        rawValue
    }

    public var displayName: String {
        switch self {
        case .none: return "None"
        case .polished: return "Polished"
        case .casual: return "Casual"
        case .chill: return "Chill"
        }
    }

    public var description: String {
        switch self {
        case .none:
            return "Use the normal post-processed dictation text without KeyVox Vibes."
        case .polished:
            return "Rewrite dictated text while preserving the original intent and structure."
        case .casual:
            return "Remove filler words, format text, and preserve the original tone."
        case .chill:
            return "Lowercase with limited punctuation and no filler words for a relaxed vibe."
        }
    }

    public var exampleText: String {
        exampleText(for: .whisper)
    }

    public func exampleText(for dictationModel: StyleRewriteDictationModel) -> String {
        switch dictationModel {
        case .whisper:
            return whisperExampleText
        case .parakeet:
            return parakeetExampleText
        }
    }

    private var whisperExampleText: String {
        switch self {
        case .none:
            return "Tell John, uh, like, immediately, the concert is gonna start at 5.30 and it's 10 bucks."
        case .casual:
            return "Tell John like, immediately, the concert is gonna start at 5:30 and it's $10."
        case .polished:
            return "Tell John immediately, the concert is going to start at 5:30 and it's $10."
        case .chill:
            return "tell john like immediately the concert is gonna start at 530 and its $10"
        }
    }

    private var parakeetExampleText: String {
        switch self {
        case .none:
            return "Tell John, uh like immediately the concert is gonna start at five thirty and it's ten bucks."
        case .casual:
            return "Tell John like immediately the concert is gonna start at 5:30 and it's $10."
        case .polished:
            return "Tell John immediately, the concert is going to start at 5:30 and it's $10."
        case .chill:
            return "tell john like immediately the concert is gonna start at 530 and its $10"
        }
    }

    public var usesModelRewrite: Bool {
        switch self {
        case .none:
            return false
        case .polished, .casual, .chill:
            return true
        }
    }

    public func resolvedForModelAvailability(_ isModelAvailable: Bool) -> StyleRewriteStyle {
        if usesModelRewrite && !isModelAvailable {
            return .none
        }

        return self
    }
}

public enum StyleRewriteDictationConfiguration {
    public static let modelContextTokenLimit = 32_768
    public static let modelMaximumGenerationTokenLimit = 8_192
    public static let defaultMaximumResponseTokens = modelMaximumGenerationTokenLimit
    public static let polishedLoRASystemPrompt = "Polish this dictated text. Remove spoken filler and false starts. Convert ain't to standard English. Preserve meaning, structure, and paragraph breaks. Do not drop, duplicate, merge, reorder, or replace paragraph content. Use numerals where appropriate. Output only the result."
    public static let casualLoRASystemPrompt = "Lightly clean this dictated text. Remove clear filler except keep the word like. Preserve slang, profanity, grammar, meaning, lists, and paragraph breaks. Format numbers, dates, money, and percentages when clear. Output only the result."

    public static func request(
        for style: StyleRewriteStyle,
        baseText: String,
        deterministicVariants: [StyleRewriteInputVariant] = [],
        contextTokenLimit: Int = modelContextTokenLimit,
        maximumResponseTokens: Int = defaultMaximumResponseTokens
    ) -> TextTransformRequest? {
        switch style {
        case .none:
            return nil
        case .polished:
            return polishedRequest(
                baseText: baseText,
                deterministicVariants: deterministicVariants,
                contextTokenLimit: contextTokenLimit,
                maximumResponseTokens: maximumResponseTokens
            )
        case .casual:
            return casualRequest(
                baseText: baseText,
                deterministicVariants: deterministicVariants,
                contextTokenLimit: contextTokenLimit,
                maximumResponseTokens: maximumResponseTokens
            )
        case .chill:
            return chillRequest(
                baseText: baseText,
                deterministicVariants: deterministicVariants,
                contextTokenLimit: contextTokenLimit,
                maximumResponseTokens: maximumResponseTokens
            )
        }
    }

    private static func polishedRequest(
        baseText: String,
        deterministicVariants: [StyleRewriteInputVariant],
        contextTokenLimit: Int,
        maximumResponseTokens: Int
    ) -> TextTransformRequest {
        return TextTransformRequest(
            baseText: baseText,
            styleIdentifier: StyleRewriteStyle.polished.styleIdentifier,
            instructions: polishedLoRASystemPrompt,
            promptPrefix: "",
            contextTokenLimit: contextTokenLimit,
            expectedOutputExpansionRatio: 0.75,
            safetyMarginTokens: 384,
            maximumResponseTokens: maximumResponseTokens,
            deterministicVariants: deterministicVariants
        )
    }

    private static func casualRequest(
        baseText: String,
        deterministicVariants: [StyleRewriteInputVariant],
        contextTokenLimit: Int,
        maximumResponseTokens: Int
    ) -> TextTransformRequest {
        return TextTransformRequest(
            baseText: baseText,
            styleIdentifier: StyleRewriteStyle.casual.styleIdentifier,
            instructions: casualLoRASystemPrompt,
            promptPrefix: "",
            contextTokenLimit: contextTokenLimit,
            expectedOutputExpansionRatio: 0.75,
            safetyMarginTokens: 384,
            maximumResponseTokens: maximumResponseTokens,
            deterministicVariants: deterministicVariants
        )
    }

    private static func chillRequest(
        baseText: String,
        deterministicVariants: [StyleRewriteInputVariant],
        contextTokenLimit: Int,
        maximumResponseTokens: Int
    ) -> TextTransformRequest {
        let cleanupRequest = casualRequest(
            baseText: baseText,
            deterministicVariants: deterministicVariants,
            contextTokenLimit: contextTokenLimit,
            maximumResponseTokens: maximumResponseTokens
        )

        return TextTransformRequest(
            baseText: baseText,
            styleIdentifier: StyleRewriteStyle.chill.styleIdentifier,
            instructions: cleanupRequest.instructions,
            promptPrefix: cleanupRequest.promptPrefix,
            promptSuffix: cleanupRequest.promptSuffix,
            contextTokenLimit: cleanupRequest.contextTokenLimit,
            expectedOutputExpansionRatio: cleanupRequest.expectedOutputExpansionRatio,
            safetyMarginTokens: cleanupRequest.safetyMarginTokens,
            maximumResponseTokens: cleanupRequest.maximumResponseTokens,
            deterministicVariants: cleanupRequest.deterministicVariants
        )
    }
}
