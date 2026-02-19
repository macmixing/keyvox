import Foundation

@MainActor
final class TranscriptionPostProcessor {
    private static let domainLikeTokenRegex: NSRegularExpression? = try? NSRegularExpression(
        pattern: #"(?i)^(?:https?://)?(?:www\.)?[a-z0-9\-]+(?:\.[a-z0-9\-]+)+/?$"#,
        options: []
    )
    private static let commonTopLevelDomains: Set<String> = [
        "com", "net", "org", "io", "app", "dev", "ai", "co", "me", "edu", "gov",
        "us", "uk", "ca", "au", "de", "fr", "jp"
    ]

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
        let textStartNormalized = capitalizeAtTextStart(whitespaceNormalized)
        let sentenceStartNormalized = capitalizeAfterSentenceBoundary(textStartNormalized)
        let lineStartNormalized = capitalizeAfterLineBreak(sentenceStartNormalized)
        let output = appendTerminalPeriodIfEndingInFormattedTime(lineStartNormalized)
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

    private func capitalizeAtTextStart(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let regex = try? NSRegularExpression(
            pattern: #"^(\s*["'“”‘’\(\[\{]*)([a-z])"#,
            options: []
        ) else {
            return text
        }

        let nsText = text as NSString
        let range = NSRange(location: 0, length: nsText.length)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else { return text }
        if isAddressOrURLToken(firstToken(in: text)) { return text }

        let prefix = nsText.substring(with: match.range(at: 1))
        let nextLetter = nsText.substring(with: match.range(at: 2)).uppercased()
        let mutable = NSMutableString(string: text)
        mutable.replaceCharacters(in: match.range, with: "\(prefix)\(nextLetter)")
        return mutable as String
    }

    private func capitalizeAfterSentenceBoundary(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let boundaryRegex = try? NSRegularExpression(
            pattern: #"(?<!\d)([.!?;:…]["'”’\)\]\}]*)(\s*)([a-z])"#,
            options: []
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
            let firstToken = tokenTail.split(whereSeparator: \.isWhitespace).first.map(String.init) ?? ""
            if isAddressOrURLToken(firstToken) {
                continue
            }

            let boundaryText = nsText.substring(with: match.range(at: 1))
            if boundaryText.first == "." {
                if isLikelyDomainBoundary(text, dotLocation: match.range(at: 1).location) {
                    continue
                }

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

    private func capitalizeAfterLineBreak(_ text: String) -> String {
        guard !text.isEmpty else { return text }
        guard let lineBreakRegex = try? NSRegularExpression(
            pattern: #"(\n)([ \t]*["'“”‘’\(\[\{]*)([a-z])"#,
            options: []
        ) else {
            return text
        }

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        let matches = lineBreakRegex.matches(in: text, options: [], range: fullRange)
        guard !matches.isEmpty else { return text }

        let mutable = NSMutableString(string: text)
        for match in matches.reversed() {
            let tokenStart = match.range(at: 3).location
            guard !lineStartsWithAddressOrURL(in: nsText, from: tokenStart) else { continue }
            let newline = nsText.substring(with: match.range(at: 1))
            let prefix = nsText.substring(with: match.range(at: 2))
            let nextLetter = nsText.substring(with: match.range(at: 3)).uppercased()
            mutable.replaceCharacters(in: match.range, with: "\(newline)\(prefix)\(nextLetter)")
        }

        return mutable as String
    }

    private func lineStartsWithAddressOrURL(in text: NSString, from location: Int) -> Bool {
        guard location >= 0, location < text.length else { return false }
        let suffix = text.substring(with: NSRange(location: location, length: text.length - location))
        let line = suffix.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? ""
        let firstToken = firstToken(in: line)
        guard !firstToken.isEmpty else { return false }
        return isAddressOrURLToken(firstToken)
    }

    private func isAddressOrURLToken(_ token: String) -> Bool {
        let stripped = token.trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}.,;:!?"))
        guard !stripped.isEmpty else { return false }

        let lowered = stripped.lowercased()
        if lowered.contains("@") {
            let parts = lowered.split(separator: "@", maxSplits: 1, omittingEmptySubsequences: false)
            if parts.count == 2, !parts[0].isEmpty, parts[1].contains(".") {
                return true
            }
        }

        var candidate = lowered
        if candidate.hasPrefix("http://") {
            candidate.removeFirst("http://".count)
        } else if candidate.hasPrefix("https://") {
            candidate.removeFirst("https://".count)
        }
        if let hostOnly = candidate.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false).first {
            candidate = String(hostOnly)
        }

        let range = NSRange(location: 0, length: (candidate as NSString).length)
        if let domainRegex = Self.domainLikeTokenRegex,
           domainRegex.firstMatch(in: candidate, options: [], range: range) != nil {
            return true
        }
        return false
    }

    private func firstToken(in text: String) -> String {
        text
            .split(whereSeparator: \.isWhitespace)
            .first
            .map(String.init) ?? ""
    }

    private func isLikelyDomainBoundary(_ text: String, dotLocation: Int) -> Bool {
        guard dotLocation >= 0 else { return false }
        let nsText = text as NSString
        guard dotLocation < nsText.length else { return false }

        var start = dotLocation
        while start > 0 {
            guard let scalar = UnicodeScalar(nsText.character(at: start - 1)) else { break }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                break
            }
            start -= 1
        }

        var end = dotLocation + 1
        while end < nsText.length {
            guard let scalar = UnicodeScalar(nsText.character(at: end)) else { break }
            if CharacterSet.whitespacesAndNewlines.contains(scalar) {
                break
            }
            end += 1
        }

        let tokenRange = NSRange(location: start, length: end - start)
        guard tokenRange.length > 0 else { return false }

        let token = nsText.substring(with: tokenRange)
            .trimmingCharacters(in: CharacterSet(charactersIn: "\"'“”‘’()[]{}"))
        guard !token.contains("@"), token.contains(".") else { return false }

        guard let regex = Self.domainLikeTokenRegex else { return false }
        let fullRange = NSRange(location: 0, length: (token as NSString).length)
        guard regex.firstMatch(in: token, options: [], range: fullRange) != nil else { return false }

        let normalized = token.lowercased()
        if normalized.hasPrefix("http://") || normalized.hasPrefix("https://") || normalized.hasPrefix("www.") {
            return true
        }

        let dotCount = normalized.filter { $0 == "." }.count
        if dotCount >= 2 {
            return true
        }

        guard let tld = normalized.split(separator: ".").last.map(String.init) else { return false }
        return Self.commonTopLevelDomains.contains(tld)
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
