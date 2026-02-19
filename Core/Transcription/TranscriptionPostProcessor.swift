import Foundation

@MainActor
final class TranscriptionPostProcessor {
    private let enablePhoneticMatcher = true
    private let vocabularyNormalizer = CustomVocabularyNormalizer()
    private let dictionaryMatcher = DictionaryMatcher()
    private let listFormattingEngine = ListFormattingEngine()
    private let timeExpressionNormalizer = TimeExpressionNormalizer()
    private var dictionaryFingerprint = ""

    // Keep teardown executor-agnostic to avoid runtime deinit crashes in test host.
    nonisolated deinit {}

    func updateDictionaryEntries(_ entries: [DictionaryEntry]) {
        let fingerprint = fingerprint(for: entries)
        guard fingerprint != dictionaryFingerprint else { return }
        dictionaryFingerprint = fingerprint
        dictionaryMatcher.rebuildIndex(entries: entries)
    }

    func process(
        _ text: String,
        dictionaryEntries: [DictionaryEntry],
        renderMode: ListRenderMode,
        listFormattingEnabled: Bool = true
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
        let emailNormalizedInput = EmailAddressTextNormalization.normalize(in: text)
        #if DEBUG
        logPipelineStage("emailNormalizedInput", emailNormalizedInput)
        #endif

        let normalized: String
        if enablePhoneticMatcher {
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
            normalized = matchResult.text
        } else {
            normalized = vocabularyNormalizer.normalize(emailNormalizedInput, with: dictionaryEntries)
            #if DEBUG
            logPipelineStage("vocabularyNormalized", normalized)
            #endif
        }

        let idiomNormalized = normalizeIdioms(in: normalized)
        #if DEBUG
        logPipelineStage("idiomNormalized", idiomNormalized)
        #endif
        let listFormatted = listFormattingEnabled
            ? listFormattingEngine.formatIfNeeded(idiomNormalized, renderMode: renderMode)
            : idiomNormalized
        #if DEBUG
        logPipelineStage("listFormatted", listFormatted)
        #endif
        let laughterNormalized = normalizeLaughterExpressions(in: listFormatted)
        #if DEBUG
        logPipelineStage("laughterNormalized", laughterNormalized)
        #endif
        let timeNormalized = normalizeTimeExpressions(in: laughterNormalized)
        #if DEBUG
        logPipelineStage("timeNormalized", timeNormalized)
        #endif
        let emailNormalizedOutput = EmailAddressTextNormalization.normalize(in: timeNormalized)
        #if DEBUG
        logPipelineStage("emailNormalizedOutput", emailNormalizedOutput)
        #endif
        let whitespaceNormalized = normalizeOutputWhitespace(emailNormalizedOutput, renderMode: renderMode)
        let leadingConjunctionNormalized = capitalizeLeadingAndAtTextStart(whitespaceNormalized)
        let sentenceStartNormalized = capitalizeAfterSentenceBoundary(leadingConjunctionNormalized)
        let output = appendTerminalPeriodIfEndingInFormattedTime(sentenceStartNormalized)
        #if DEBUG
        logPipelineStage("output", output)
        #endif
        return output
    }

    private func normalizeOutputWhitespace(_ text: String, renderMode: ListRenderMode) -> String {
        switch renderMode {
        case .singleLineInline:
            return text
                .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .multiline:
            let normalizedLines = text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in
                    String(line)
                        .replacingOccurrences(of: "[\\t ]+", with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }

            var collapsedLines: [String] = []
            collapsedLines.reserveCapacity(normalizedLines.count)

            var previousWasBlank = false
            for line in normalizedLines {
                let isBlank = line.isEmpty
                if isBlank {
                    if collapsedLines.isEmpty || previousWasBlank {
                        continue
                    }
                    collapsedLines.append("")
                    previousWasBlank = true
                } else {
                    collapsedLines.append(line)
                    previousWasBlank = false
                }
            }

            while collapsedLines.first?.isEmpty == true {
                collapsedLines.removeFirst()
            }
            while collapsedLines.last?.isEmpty == true {
                collapsedLines.removeLast()
            }

            return collapsedLines.joined(separator: "\n")
        }
    }

    private func appendTerminalPeriodIfEndingInFormattedTime(_ text: String) -> String {
        guard !text.isEmpty else { return text }

        // Respect existing terminal punctuation, including punctuation before closing quotes/brackets.
        if text.range(of: #"[.!?…][\"'”’\)\]\}]*\s*$"#, options: .regularExpression) != nil {
            return text
        }

        let terminalTimePattern = #"(?i)\b(?:[1-9]|1[0-2]):[0-5][0-9]\s(?:AM|PM)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: terminalTimePattern) else { return text }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return text
        }

        // Only treat this as sentence-like if there is prose before the terminal time.
        let prefix = nsText.substring(to: match.range.location)
        guard prefix.range(of: #"\b[A-Za-z]{3,}\b"#, options: .regularExpression) != nil else {
            return text
        }

        return text + "."
    }

    private func capitalizeLeadingAndAtTextStart(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\s*["'“”‘’\(\[\{]*)(and)\b"#,
            options: [.caseInsensitive]
        ) else {
            return text
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return text }

        let prefix = nsText.substring(with: match.range(at: 1))
        let mutable = NSMutableString(string: text)
        mutable.replaceCharacters(in: match.range, with: "\(prefix)And")
        return mutable as String
    }

    private func capitalizeAfterSentenceBoundary(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let boundaryRegex = try? NSRegularExpression(
            pattern: #"(?<!\d)([.!?;:…]["'”’\)\]\}]*)(\s*)([a-z])"#,
            options: []
        ),
        let emailPrefixRegex = try? NSRegularExpression(
            pattern: #"^[a-z0-9._%+\-]+@"#,
            options: [.caseInsensitive]
        ) else {
            return text
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = boundaryRegex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let tokenStart = match.range(at: 3).location
            let tokenTail = nsText.substring(with: NSRange(location: tokenStart, length: nsText.length - tokenStart))
            let tokenTailRange = NSRange(location: 0, length: (tokenTail as NSString).length)
            if emailPrefixRegex.firstMatch(in: tokenTail, options: [], range: tokenTailRange) != nil {
                continue
            }

            let boundaryText = nsText.substring(with: match.range(at: 1))
            if boundaryText.first == "." {
                let prefixText = nsText.substring(to: match.range(at: 1).location)
                let previousToken = prefixText.split(whereSeparator: \.isWhitespace).last.map(String.init) ?? ""
                if previousToken.contains("@") {
                    continue
                }
            }

            let prefix = nsText.substring(with: match.range(at: 1))
            let spacing = nsText.substring(with: match.range(at: 2))
            let separator = spacing.isEmpty ? " " : spacing
            let nextLetter = nsText.substring(with: match.range(at: 3)).uppercased()
            mutable.replaceCharacters(in: match.range, with: "\(prefix)\(separator)\(nextLetter)")
        }

        return mutable as String
    }

    private func fingerprint(for entries: [DictionaryEntry]) -> String {
        entries
            .map { "\($0.id.uuidString):\($0.phrase)" }
            .sorted()
            .joined(separator: "|")
    }

    private func normalizeLaughterExpressions(in text: String) -> String {
        replacingMatches(pattern: #"\bha\s+ha\b"#, in: text) { _, _ in
            "haha"
        }
    }

    private func normalizeIdioms(in text: String) -> String {
        replacingMatches(pattern: #"\bhole\s+in\s+one\b"#, in: text) { _, _ in
            "hole-in-one"
        }
    }

    private func normalizeTimeExpressions(in text: String) -> String {
        timeExpressionNormalizer.normalize(in: text)
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
