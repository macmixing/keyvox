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
            Edit in this order:
            Remove spoken filler and disfluencies from the whole input, including um, uh, the filler word like, you know, I mean, and repeated starts.
            Remove filler after punctuation and keep the sentence that follows it.
            When a sentence begins with spoken filler, delete only the filler and keep that sentence's meaningful words.
            In requests, delete like before please.
            Delete standalone like when removing it does not change the speaker's meaning.
            Keep every meaningful word and phrase around removed filler.
            Repair spacing and punctuation after filler is removed.
            Copyedit clear grammar, subject-verb agreement, casing, repeated words, obvious transcription errors, dictated dates, dollar amounts, and numbers.
            Preserve the speaker's meaning, structure, sentence type, message type, tone, formality, emotional wording, profanity, names, URLs, email addresses, emoji, symbols, and code-like text.
            Preserve meaningful openers and short meaningful interjections.
            Do not summarize, soften, censor, reorder, split, merge, add, or duplicate content.
            Never add greetings, sign-offs, names, placeholders, headings, bullets, commentary, labels, or explanations.

            Examples:

            Input: Hey, um, are you okay?
            Output: Hey, are you okay?

            Input: Hey, um what are you doing, um tomorrow?
            Output: Hey, what are you doing tomorrow?

            Input: Yo, um what are you doing?
            Output: Yo, what are you doing?

            Input: Um, what's up?
            Output: What's up?

            Input: We made it. Um, please send the file.
            Output: We made it. Please send the file.

            Input: Is everything okay? Um, are you still having trouble?
            Output: Is everything okay? Are you still having trouble?

            Input: I am, like, trying to figure out dinner.
            Output: I am trying to figure out dinner.

            Input: Are you um feeling this vibe? It's like pretty polished. Try it out.
            Output: Are you feeling this vibe? It's pretty polished. Try it out.

            Input: I don't know why, um, this keeps happening.
            Output: I don't know why this keeps happening.

            Input: I don't know why, um, you're making this harder, but can you like please stop?
            Output: I don't know why you're making this harder, but can you please stop?

            Input: I don't get why, um, you're being so rude, but can you like please stop?
            Output: I don't get why you're being so rude, but can you please stop?

            Input: Are you um feeling this vibe? It's like pretty polished. Try it out.
            Output: Are you feeling this vibe? It's pretty polished. Try it out.

            Input: Let's meet on May third.
            Output: Let's meet on May 3rd.

            Input: I bought that for four hundred and ninety nine dollars.
            Output: I bought that for $499.

            Input: Me and Sarah was talking about the launch.
            Output: Me and Sarah were talking about the launch.
            """,
            promptPrefix: """
            Copyedit this dictated text.
            Remove spoken filler first, then apply polished copyediting.
            Remove filler such as um, uh, the filler word like, you know, I mean, and repeated starts from the whole text.
            Remove filler after punctuation and keep the sentence that follows it.
            When a sentence begins with spoken filler, delete only the filler and keep that sentence's meaningful words.
            In requests, delete like before please.
            Delete standalone like when removing it does not change the speaker's meaning.
            Keep every meaningful word around removed filler.
            Preserve meaning, structure, sentence type, tone, emotional wording, profanity, and meaningful openers.
            Do not summarize, soften, censor, split, merge, add, or duplicate content.
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
            Preserve the speaker's meaning, opener, structure, wording, word order, casing, punctuation, sentence type, message type, tone, slang, and formality.
            Do not paraphrase, summarize, improve, soften, intensify, reformat, recase, or make the text more casual.
            Preserve existing paragraph breaks, numbered lists, bulleted lists, list markers, list line breaks, and the line before a list.
            If the input has multiple lines, keep the same line structure and line order.
            Do not flatten a list into a sentence, comma-separated phrase, or single line.
            Clean only the words inside each list item without moving list items or deleting the list introduction.
            Do not replace words or phrases with synonyms.
            Do not add words, greetings, sign-offs, names, placeholders, headings, commentary, labels, or explanations.
            Keep every meaningful input word from beginning to end.
            Remove only words like um, uh, accidental repeated starts, and clear speech stumbles that do not add meaning.
            Short openers, interjections, address words, and tone-setting words are meaningful text, not filler.
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

            Input: I need to pick up a couple of things from the store:

            1. Um apples
            2. Bananas
            3. Uh grapes
            
            Output: I need to pick up a couple of things from the store:

            1. Apples
            2. Bananas
            3. Grapes

            \(contextualFormattingExamples)
            """,
            promptPrefix: """
            Remove only obvious speech disfluencies from this dictated text.
            Keep the original opener, structure, casing, punctuation, wording, tone, slang, and formality.
            Preserve existing paragraph breaks, numbered lists, bulleted lists, list markers, list line breaks, and the line before a list.
            If the input has multiple lines, keep the same line structure and line order.
            Do not flatten a list into a sentence, comma-separated phrase, or single line.
            Clean only the words inside each list item without moving list items or deleting the list introduction.
            Keep every meaningful input word from beginning to end.
            Short openers, interjections, address words, and tone-setting words are meaningful text, not filler.
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
