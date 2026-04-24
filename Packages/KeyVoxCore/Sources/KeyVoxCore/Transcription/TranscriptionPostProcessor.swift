import Foundation

@MainActor
public final class TranscriptionPostProcessor {
    private let dictionaryMatcher = DictionaryMatcher()
    private let listFormattingEngine = ListFormattingEngine()
    private let laughterNormalizer = LaughterNormalizer()
    private let characterSpamNormalizer = CharacterSpamNormalizer()
    private let timeExpressionNormalizer = TimeExpressionNormalizer()
    private let dateNormalizer = DateNormalizer()
    private let mathExpressionNormalizer = MathExpressionNormalizer()
    private let thousandsGroupingNormalizer = ThousandsGroupingNormalizer()
    private let colonNormalizer = ColonNormalizer()
    private let allCapsOverrideNormalizer = AllCapsOverrideNormalizer()
    private let whitespaceNormalizer = WhitespaceNormalizer()
    private let capitalizationNormalizer = SentenceCapitalizationNormalizer()
    private let terminalPunctuationNormalizer = TerminalPunctuationNormalizer()
    private var dictionaryFingerprint = ""

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

    public init() {}

    public func updateDictionaryEntries(_ entries: [DictionaryEntry]) {
        let effectiveEntries = DictionaryBuiltInEntries.effectiveEntries(merging: entries)
        let fingerprint = fingerprint(for: effectiveEntries)
        guard fingerprint != dictionaryFingerprint else { return }
        dictionaryFingerprint = fingerprint
        dictionaryMatcher.rebuildIndex(entries: effectiveEntries)
    }

    public func process(
        _ text: String,
        dictionaryEntries: [DictionaryEntry],
        renderMode: ListRenderMode,
        listFormattingEnabled: Bool = true,
        forceAllCaps: Bool = false,
        languageCode: String? = nil
    ) -> String {
        guard !text.isEmpty else { return "" }

        #if DEBUG
        logPipelineStage("input", text)
        print(
            "[KVXPost] settings listFormattingEnabled=\(listFormattingEnabled) " +
            "renderMode=\(renderMode) dictionaryEntries=\(dictionaryEntries.count)"
        )
        #endif

        updateDictionaryEntries(dictionaryEntries)
        let emailNormalizedInput = EmailAddressNormalizer.normalize(in: text)
        #if DEBUG
        logPipelineStage("emailNormalizedInput", emailNormalizedInput)
        #endif

        let matchResult = dictionaryMatcher.apply(to: emailNormalizedInput)
        #if DEBUG
        if matchResult.stats.attempted > 0 {
            print(
                "[DictionaryMatcher] attempts=\(matchResult.stats.attempted) accepted=\(matchResult.stats.accepted) " +
                "lowScore=\(matchResult.stats.rejectedLowScore) ambiguity=\(matchResult.stats.rejectedAmbiguity) " +
                "commonWord=\(matchResult.stats.rejectedCommonWord) short=\(matchResult.stats.rejectedShortToken) " +
                "overlap=\(matchResult.stats.rejectedOverlap)"
            )
        }
        logPipelineStage("dictionaryNormalized", matchResult.text)
        #endif
        let normalized = matchResult.text

        let idiomNormalized = normalizeIdioms(in: normalized)
        #if DEBUG
        logPipelineStage("idiomNormalized", idiomNormalized)
        #endif
        let colonNormalized = colonNormalizer.normalize(in: idiomNormalized)
        #if DEBUG
        logPipelineStage("colonNormalized", colonNormalized)
        #endif
        let spokenQuantityNormalized = thousandsGroupingNormalizer.normalizeSpokenQuantities(in: colonNormalized)
        #if DEBUG
        logPipelineStage("spokenQuantityNormalized", spokenQuantityNormalized)
        #endif
        let mathNormalized = mathExpressionNormalizer.normalize(in: spokenQuantityNormalized)
        #if DEBUG
        logPipelineStage("mathNormalized", mathNormalized)
        #endif
        let listFormatted = listFormattingEnabled
            ? listFormattingEngine.formatIfNeeded(mathNormalized, renderMode: renderMode, languageCode: languageCode)
            : mathNormalized
        #if DEBUG
        logPipelineStage("listFormatted", listFormatted)
        #endif
        let laughterNormalized = laughterNormalizer.normalize(in: listFormatted)
        #if DEBUG
        logPipelineStage("laughterNormalized", laughterNormalized)
        #endif
        let characterSpamNormalized = characterSpamNormalizer.normalize(in: laughterNormalized)
        #if DEBUG
        logPipelineStage("characterSpamNormalized", characterSpamNormalized)
        #endif
        let timeNormalized = normalizeTimeExpressions(in: characterSpamNormalized)
        #if DEBUG
        logPipelineStage("timeNormalized", timeNormalized)
        #endif
        let dateNormalized = normalizeDates(in: timeNormalized)
        #if DEBUG
        logPipelineStage("dateNormalized", dateNormalized)
        #endif
        let emailNormalizedOutput = EmailAddressNormalizer.normalize(in: dateNormalized)
        #if DEBUG
        logPipelineStage("emailNormalizedOutput", emailNormalizedOutput)
        #endif
        let websiteNormalizedOutput = WebsiteNormalizer.normalizeDomainCasing(in: emailNormalizedOutput)
        #if DEBUG
        logPipelineStage("websiteNormalizedOutput", websiteNormalizedOutput)
        #endif
        let groupedNumericOutput = thousandsGroupingNormalizer.normalize(in: websiteNormalizedOutput)
        #if DEBUG
        logPipelineStage("groupedNumericOutput", groupedNumericOutput)
        #endif
        let whitespaceNormalized = whitespaceNormalizer.normalize(groupedNumericOutput, renderMode: renderMode)
        #if DEBUG
        logPipelineStage("whitespaceNormalized", whitespaceNormalized)
        #endif
        let sentenceNormalized = capitalizationNormalizer.normalizeSentenceStarts(in: whitespaceNormalized)
        #if DEBUG
        logPipelineStage("sentenceNormalized", sentenceNormalized)
        #endif
        let punctuatedOutput = terminalPunctuationNormalizer.appendTerminalPeriodIfEndingInFormattedTime(sentenceNormalized)
        let output = allCapsOverrideNormalizer.normalize(in: punctuatedOutput, isEnabled: forceAllCaps)
        #if DEBUG
        if forceAllCaps {
            logPipelineStage("allCapsOverride", output)
        }
        logPipelineStage("output", output)
        #endif
        return output
    }

    private func fingerprint(for entries: [DictionaryEntry]) -> String {
        entries
            .map { "\($0.id.uuidString):\($0.phrase)" }
            .sorted()
            .joined(separator: "|")
    }

    private func normalizeIdioms(in text: String) -> String {
        replacingMatches(pattern: #"\bhole\s+in\s+one\b"#, in: text) { _, _ in
            "hole-in-one"
        }
    }

    private func normalizeTimeExpressions(in text: String) -> String {
        timeExpressionNormalizer.normalize(in: text)
    }

    private func normalizeDates(in text: String) -> String {
        dateNormalizer.normalize(in: text)
    }

    private func replacingMatches(
        pattern: String,
        in text: String,
        transform: (_ match: NSTextCheckingResult, _ nsText: NSString) -> String?
    ) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return text
        }

        let nsText = text as NSString
        let mutable = NSMutableString(string: text)
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = regex.matches(in: text, options: [], range: fullRange)
        for match in matches.reversed() {
            guard let replacement = transform(match, nsText) else { continue }
            mutable.replaceCharacters(in: match.range, with: replacement)
        }

        return mutable as String
    }

    #if DEBUG
    private static let debugEmailLikeRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: "[A-Z0-9._%+\\-]+@[A-Z0-9.\\-]+\\.[A-Z]{2,}",
        options: [.caseInsensitive]
    )

    private func logPipelineStage(_ stage: String, _ value: String) {
        let summary = debugTextSummary(value)
        if rawDebugTextLoggingEnabled {
            let escaped = truncatedDebugEscaped(value, maxCharacters: 400)
            print("[KVXPost] \(stage) \(summary) text=\(escaped)")
        } else {
            print("[KVXPost] \(stage) \(summary)")
        }
    }

    private var rawDebugTextLoggingEnabled: Bool {
        ProcessInfo.processInfo.environment["KVX_DEBUG_LOG_RAW_TEXT"] == "1"
    }

    private func debugTextSummary(_ text: String) -> String {
        let chars = text.count
        let words = text.split(whereSeparator: \.isWhitespace).count
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).count
        let atSigns = text.filter { $0 == "@" }.count
        let emailLikeCount: Int = {
            guard let regex = Self.debugEmailLikeRegex else { return 0 }
            let nsText = text as NSString
            let range = NSRange(location: 0, length: nsText.length)
            return regex.numberOfMatches(in: text, options: [], range: range)
        }()
        return "chars=\(chars) words=\(words) lines=\(lines) at=\(atSigns) emailLike=\(emailLikeCount)"
    }

    private func truncatedDebugEscaped(_ text: String, maxCharacters: Int) -> String {
        let escaped = text.replacingOccurrences(of: "\n", with: "\\n")
        guard escaped.count > maxCharacters else { return escaped }
        let end = escaped.index(escaped.startIndex, offsetBy: maxCharacters)
        return "\(escaped[..<end])..."
    }
    #endif
}
