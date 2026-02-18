import Foundation

@MainActor
final class TranscriptionPostProcessor {
    private let enablePhoneticMatcher = true
    private let vocabularyNormalizer = CustomVocabularyNormalizer()
    private let dictionaryMatcher = DictionaryMatcher()
    private let listFormattingEngine = ListFormattingEngine()
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

        updateDictionaryEntries(dictionaryEntries)

        let normalized: String
        if enablePhoneticMatcher {
            let matchResult = dictionaryMatcher.apply(to: text)
            #if DEBUG
            if matchResult.stats.attempted > 0 {
                print(
                    "[DictionaryMatcher] attempts=\(matchResult.stats.attempted) accepted=\(matchResult.stats.accepted) " +
                    "lowScore=\(matchResult.stats.rejectedLowScore) ambiguity=\(matchResult.stats.rejectedAmbiguity) " +
                    "commonWord=\(matchResult.stats.rejectedCommonWord) short=\(matchResult.stats.rejectedShortToken) " +
                    "overlap=\(matchResult.stats.rejectedOverlap)"
                )
            }
            #endif
            normalized = matchResult.text
        } else {
            normalized = vocabularyNormalizer.normalize(text, with: dictionaryEntries)
        }

        let idiomNormalized = normalizeIdioms(in: normalized)
        let listFormatted = listFormattingEnabled
            ? listFormattingEngine.formatIfNeeded(idiomNormalized, renderMode: renderMode)
            : idiomNormalized
        let laughterNormalized = normalizeLaughterExpressions(in: listFormatted)
        let timeNormalized = normalizeTimeExpressions(in: laughterNormalized)
        return normalizeOutputWhitespace(timeNormalized, renderMode: renderMode)
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
        guard !text.isEmpty else { return text }

        let daypartPattern =
            "(?:in the morning|this morning|in the afternoon|this afternoon|in the evening|this evening|at night|tonight)"
        let amMeridiemPattern = "(?:a\\.?m\\.?|am|a\\.?n\\.?|an)"
        let pmMeridiemPattern = "(?:p\\.?m\\.?|pm)"
        let meridiemPattern = "(?:\(amMeridiemPattern)|\(pmMeridiemPattern))"

        var output = text

        // Normalize spaced/compact meridiem forms while preserving spoken structure.
        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2]):([0-5][0-9])[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            let meridiem = nsText.substring(with: match.range(at: 3))
            return "\(hour):\(minute) \(normalizedMeridiem(meridiem))"
        }

        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2])[\.-]([0-5][0-9])[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            let meridiem = nsText.substring(with: match.range(at: 3))
            return "\(hour):\(minute) \(normalizedMeridiem(meridiem))"
        }

        output = replacingMatches(
            pattern: #"\b([0-9]{3,4})[\s-]*(\#(meridiemPattern))(?=$|\s|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let digits = nsText.substring(with: match.range(at: 1))
            guard let formatted = formattedCompactTime(digits) else { return nil }
            let meridiem = nsText.substring(with: match.range(at: 2))
            return "\(formatted) \(normalizedMeridiem(meridiem))"
        }

        // Balanced fuzzy-AM pass: map "AND" only when it behaves like a terminal meridiem token.
        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2])[:\.-]([0-5][0-9])[\s-]*and\.?(?=$|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            return "\(hour):\(minute) AM"
        }

        output = replacingMatches(
            pattern: #"\b([0-9]{3,4})[\s-]*and\.?(?=$|[,;:!?\)\.])"#,
            in: output
        ) { match, nsText in
            let digits = nsText.substring(with: match.range(at: 1))
            guard let formatted = formattedCompactTime(digits) else { return nil }
            return "\(formatted) AM"
        }

        // Preserve spoken daypart phrases and only normalize malformed numeric time shape.
        output = replacingMatches(
            pattern: #"\b([1-9]|1[0-2])[\.-]([0-5][0-9])(?=\s+\#(daypartPattern)\b)"#,
            in: output
        ) { match, nsText in
            let hour = nsText.substring(with: match.range(at: 1))
            let minute = nsText.substring(with: match.range(at: 2))
            return "\(hour):\(minute)"
        }

        output = replacingMatches(
            pattern: #"\b([0-9]{3,4})(?=\s+\#(daypartPattern)\b)"#,
            in: output
        ) { match, nsText in
            let digits = nsText.substring(with: match.range(at: 1))
            return formattedCompactTime(digits)
        }

        return output
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

    private func formattedCompactTime(_ digits: String) -> String? {
        guard digits.count == 3 || digits.count == 4 else { return nil }

        let hourDigitsCount = digits.count - 2
        let hourStart = digits.startIndex
        let hourEnd = digits.index(hourStart, offsetBy: hourDigitsCount)
        let minuteStart = hourEnd
        let minuteEnd = digits.endIndex

        guard let hour = Int(digits[hourStart..<hourEnd]),
              let minute = Int(digits[minuteStart..<minuteEnd]),
              (1...12).contains(hour),
              (0...59).contains(minute) else {
            return nil
        }

        return "\(hour):\(String(format: "%02d", minute))"
    }

    private func normalizedMeridiem(_ value: String) -> String {
        let lettersOnly = value
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
        if lettersOnly == "am" || lettersOnly == "an" { return "AM" }
        if lettersOnly == "pm" { return "PM" }
        return value
    }
}
