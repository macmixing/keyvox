import Foundation

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
            return "Remove filler words while preserving the original tone and punctuation."
        case .chill:
            return "Lowercase with limited punctuation and no filler words for a relaxed vibe."
        }
    }

    public var exampleText: String {
        switch self {
        case .none:
            return "Are you um feeling this vibe? It's like pretty normal. Try it out."
        case .casual:
            return "Are you feeling this vibe? It's like pretty casual. Try it out."
        case .polished:
            return "Are you feeling this vibe? It's pretty polished. Try it out."
        case .chill:
            return "are you feeling this vibe? its like pretty chill. try it out"
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
    public static let modelContextTokenLimit = 4_096
    public static let defaultMaximumResponseTokens = 512
    private static let contextualFormattingExamples = """
    Input: I bought that for four hundred and ninety nine dollars.
    Output: I bought that for $499.

    Input: WWDC twenty twenty six should be interesting.
    Output: WWDC 2026 should be interesting.

    Input: I bought two thousand twenty six units.
    Output: I bought 2,026 units.

    Input: Let's meet on May third.
    Output: Let's meet on May 3rd.
    """

    public static func request(
        for style: StyleRewriteStyle,
        baseText: String,
        contextTokenLimit: Int = modelContextTokenLimit,
        maximumResponseTokens: Int = defaultMaximumResponseTokens
    ) -> TextTransformRequest? {
        switch style {
        case .none:
            return nil
        case .polished:
            return polishedRequest(
                baseText: baseText,
                contextTokenLimit: contextTokenLimit,
                maximumResponseTokens: maximumResponseTokens
            )
        case .casual:
            return casualRequest(
                baseText: baseText,
                contextTokenLimit: contextTokenLimit,
                maximumResponseTokens: maximumResponseTokens
            )
        case .chill:
            return chillRequest(
                baseText: baseText,
                contextTokenLimit: contextTokenLimit,
                maximumResponseTokens: maximumResponseTokens
            )
        }
    }

    private static func polishedRequest(
        baseText: String,
        contextTokenLimit: Int,
        maximumResponseTokens: Int
    ) -> TextTransformRequest {
        return TextTransformRequest(
            baseText: baseText,
            styleIdentifier: StyleRewriteStyle.polished.styleIdentifier,
            instructions: """
            You copyedit dictated text.
            Return exactly one edited version of the input text.
            Return only the edited text.
            Make polished corrections that fix clear dictated-text issues.
            Remove non-meaningful filler words, false starts, and speech disfluencies such as um, uh, like, you know, I mean, and repeated starts when they do not add meaning, even when transcription did not add commas or they appear before descriptive modifiers.
            Correct clear grammar, subject-verb agreement, punctuation, casing, repeated words, obvious transcription errors, dictated dates, dollar amounts, and numbers.
            Polished copyediting should fix clear grammar errors even when that changes the original wording.
            Do not leave a clear grammar or disfluency issue unchanged only to preserve the original wording.
            Never duplicate an input phrase that appears only once.
            Correct subject-verb agreement when the subject and verb clearly disagree.
            Preserve the speaker's meaning, opener, structure, sentence type, message type, tone, formality, emotional wording, names, URLs, email addresses, emoji, symbols, and code-like text.
            Never add greetings, sign-offs, names, placeholders, headings, bullets, commentary, labels, or explanations.
            If removing a word would change meaning, keep it.

            Examples:

            Input: Hey, um, are you okay?
            Output: Hey, are you okay?

            Input: Phase three. Yo, um what are you doing?
            Output: Phase three. Yo, what are you doing?

            Input: Hey, um what are you doing, um tomorrow?
            Output: Hey, what are you doing tomorrow?

            Input: Yo, um what are you doing?
            Output: Yo, what are you doing?

            Input: Um, what's up?
            Output: What's up?

            Input: I am, like, trying to figure out dinner.
            Output: I am trying to figure out dinner.

            Input: Are you um feeling this vibe? It's like pretty polished. Try it out.
            Output: Are you feeling this vibe? It's pretty polished. Try it out.

            Input: Why can't you fucking help me?
            Output: Why can't you help me?

            Input: Let's meet on May third.
            Output: Let's meet on May 3rd.

            Input: I bought that for four hundred and ninety nine dollars.
            Output: I bought that for $499.

            Input: Me and Sarah was talking about the launch.
            Output: Me and Sarah were talking about the launch.
            """,
            promptPrefix: """
            Copyedit this dictated text.
            Apply polished copyediting.
            Remove non-meaningful filler words, false starts, and speech disfluencies such as um, uh, like, you know, I mean, and repeated starts when they do not add meaning, even when transcription did not add commas or they appear before descriptive modifiers.
            Correct clear grammar, subject-verb agreement, punctuation, casing, dictated dates, dollar amounts, and numbers.
            Polished copyediting should fix clear grammar errors even when that changes the original wording.
            Do not leave a clear grammar or disfluency issue unchanged only to preserve the original wording.
            Never duplicate an input phrase that appears only once.
            Correct subject-verb agreement when the subject and verb clearly disagree.
            Preserve meaning, opener, structure, tone, and emotional wording.
            Return only the edited text.

            Text:

            """,
            contextTokenLimit: contextTokenLimit,
            expectedOutputExpansionRatio: 0.75,
            safetyMarginTokens: 384,
            maximumResponseTokens: maximumResponseTokens
        )
    }

    private static func casualRequest(
        baseText: String,
        contextTokenLimit: Int,
        maximumResponseTokens: Int
    ) -> TextTransformRequest {
        return TextTransformRequest(
            baseText: baseText,
            styleIdentifier: StyleRewriteStyle.casual.styleIdentifier,
            instructions: """
            You clean up casual dictated text.
            Return exactly one cleaned copy of the input text.
            Return only the cleaned text.
            Preserve the speaker's wording, word order, casing, punctuation, sentence type, message type, tone, slang, and formality.
            Do not paraphrase, summarize, improve, soften, intensify, reformat, recase, or make the text more casual.
            Do not replace words or phrases with synonyms.
            Do not add words, greetings, sign-offs, names, placeholders, headings, commentary, labels, or explanations.
            Keep every meaningful input word from beginning to end.
            Remove only words like um, uh, accidental repeated starts, and clear speech stumbles that do not add meaning.
            Remove commas that only separated removed speech disfluencies.
            If removing a disfluency exposes the real start of a sentence, use normal sentence capitalization for that remaining first word.
            Do not remove profanity, insults, slang, emphasis words, emotionally charged words, names, numbers, URLs, email addresses, emoji, symbols, or code-like text.
            Format dictated dates, dollar amounts, and numbers correctly in context, such as years, quantities, prices, and calendar dates.
            Profanity is meaningful text, not filler.
            If you are unsure whether a word is filler or meaningful, keep it.
            Keep normal spaces between words and preserve the complete cleaned copy from beginning to end.

            Examples:
            Input: Um hey, what's up man?
            Output: Hey, what's up man?

            Input: I am, like, trying to figure out dinner.
            Output: I am trying to figure out dinner.

            Input: Phase three. Yo, um what are you doing?
            Output: Phase three. Yo, what are you doing?

            Input: Hey, um what are you doing, um tomorrow?
            Output: Hey, what are you doing tomorrow?

            Input: Why can't you fucking help me?
            Output: Why can't you fucking help me?

            \(contextualFormattingExamples)
            """,
            promptPrefix: """
            Remove only obvious speech disfluencies from this dictated text.
            Keep the original casing, punctuation, wording, tone, slang, and formality.
            Keep every meaningful input word from beginning to end.
            Remove commas that only separated removed speech disfluencies.
            If removing a disfluency exposes the real start of a sentence, use normal sentence capitalization for that remaining first word.
            Keep profanity, insults, slang, emphasis words, and emotionally charged words.
            Keep emoji and symbols if they are present.
            Format dates, dollar amounts, and numbers correctly in context.
            If unsure whether a word is filler or meaningful, keep it.
            Return only the complete cleaned text.

            Text:

            """,
            contextTokenLimit: contextTokenLimit,
            expectedOutputExpansionRatio: 0.75,
            safetyMarginTokens: 384,
            maximumResponseTokens: maximumResponseTokens
        )
    }

    private static func chillRequest(
        baseText: String,
        contextTokenLimit: Int,
        maximumResponseTokens: Int
    ) -> TextTransformRequest {
        let cleanupRequest = casualRequest(
            baseText: baseText,
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
            maximumResponseTokens: cleanupRequest.maximumResponseTokens
        )
    }
}
