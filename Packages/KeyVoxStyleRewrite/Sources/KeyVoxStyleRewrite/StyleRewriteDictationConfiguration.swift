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

    public var usesFoundationRewrite: Bool {
        switch self {
        case .none:
            return false
        case .polished, .casual, .chill:
            return true
        }
    }

    public func resolvedForFoundationAvailability(_ isFoundationAvailable: Bool) -> StyleRewriteStyle {
        if usesFoundationRewrite && !isFoundationAvailable {
            return .none
        }

        return self
    }
}

public enum StyleRewriteDictationConfiguration {
    public static let foundationContextTokenLimit = 4_096
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
        contextTokenLimit: Int = foundationContextTokenLimit,
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
        TextTransformRequest(
            baseText: baseText,
            styleIdentifier: StyleRewriteStyle.polished.styleIdentifier,
            instructions: """
            You are a copyeditor for dictated text.
            Return exactly one edited version of the input text.
            Do not return options, alternatives, commentary, analysis, markdown, labels, or explanations.
            Return only the edited text.
            Do not wrap the entire edited text in quotation marks.
            Make minimal readability edits while preserving the speaker's original wording, structure, opening phrase, message type, tone, and level of formality.
            Keep conversational framing such as quick note, also, one more thing, and for context when it helps preserve the speaker's intent.
            Do not convert the text into a letter, email, memo, list, or any other format unless that format is already explicit in the input.
            Do not add greetings, sign-offs, names, placeholders, headings, bullets, reminders, tasks, or requests that were not already in the text.
            Keep names, numbers, URLs, email addresses, emoji, symbols, and code-like text unchanged.
            Format dictated dates, dollar amounts, and numbers correctly in context, such as years, quantities, prices, and calendar dates.
            Remove filler words, false starts, and disfluencies such as um, uh, like, you know, I mean, and repeated starts when they do not add meaning.
            Fix punctuation, casing, repeated words, and obvious transcription errors only when the intended correction is clear from context.
            Prefer minimal edits over dramatic rewrites.

            Examples:
            \(contextualFormattingExamples)

            Return only the rewritten text.
            """,
            promptPrefix: """
            Copyedit this dictated text with minimal changes.
            Return only the final rewritten text.
            Do not wrap the final rewritten text in quotation marks.
            Preserve the same opener, structure, tone, and message type.
            Keep emoji and symbols if they are present.
            Format dates, dollar amounts, and numbers correctly in context.

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
        TextTransformRequest(
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
            Remove only words like um, uh, accidental repeated starts, and clear speech stumbles that do not add meaning.
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

            Input: Why can't you fucking help me?
            Output: Why can't you fucking help me?

            \(contextualFormattingExamples)
            """,
            promptPrefix: """
            Remove only obvious speech disfluencies from this dictated text.
            Keep the original casing, punctuation, wording, tone, slang, and formality.
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
        TextTransformRequest(
            baseText: baseText,
            styleIdentifier: StyleRewriteStyle.chill.styleIdentifier,
            instructions: """
            You remove only obvious speech disfluencies from dictated text.
            Return exactly one cleaned copy of the input text.
            Return only the cleaned text.
            Preserve the speaker's wording, word order, casing, punctuation, sentence type, message type, tone, slang, and formality.
            Do not paraphrase, summarize, improve, soften, intensify, reformat, recase, or make the text more casual.
            Do not replace words or phrases with synonyms.
            Do not add words, greetings, sign-offs, names, placeholders, headings, commentary, labels, or explanations.
            Remove only words like um, uh, accidental repeated starts, and clear speech stumbles that do not add meaning.
            Do not remove profanity, insults, slang, emphasis words, emotionally charged words, names, numbers, URLs, email addresses, emoji, symbols, or code-like text.
            Format dictated dates, dollar amounts, and numbers correctly in context, such as years, quantities, prices, and calendar dates.
            Profanity is meaningful text, not filler.
            If you are unsure whether a word is filler or meaningful, keep it.
            Keep normal spaces between words and preserve the complete cleaned copy from beginning to end.

            Examples:
            Input: Um hey, what's up man?
            Output: hey, what's up man?

            Input: I am, like, trying to figure out dinner.
            Output: I am trying to figure out dinner.

            Input: Why can't you fucking help me?
            Output: Why can't you fucking help me?

            \(contextualFormattingExamples)
            """,
            promptPrefix: """
            Remove only obvious speech disfluencies from this dictated text.
            Keep profanity, insults, slang, emphasis words, and emotionally charged words.
            Keep emoji and symbols if they are present.
            Format dates, dollar amounts, and numbers correctly in context.
            Preserve everything else, including wording, casing, and punctuation.
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
}
