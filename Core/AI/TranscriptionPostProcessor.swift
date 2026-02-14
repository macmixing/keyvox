import Foundation

@MainActor
final class TranscriptionPostProcessor {
    private let enablePhoneticMatcher = true
    private let vocabularyNormalizer = CustomVocabularyNormalizer()
    private let dictionaryMatcher = DictionaryMatcher()
    private let listFormattingEngine = ListFormattingEngine()
    private var dictionaryFingerprint = ""

    func updateDictionaryEntries(_ entries: [DictionaryEntry]) {
        let fingerprint = fingerprint(for: entries)
        guard fingerprint != dictionaryFingerprint else { return }
        dictionaryFingerprint = fingerprint
        dictionaryMatcher.rebuildIndex(entries: entries)
    }

    func process(_ text: String, dictionaryEntries: [DictionaryEntry], renderMode: ListRenderMode) -> String {
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

        let listFormatted = listFormattingEngine.formatIfNeeded(normalized, renderMode: renderMode)
        return normalizeOutputWhitespace(listFormatted, renderMode: renderMode)
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
                .filter { !$0.isEmpty }

            return normalizedLines.joined(separator: "\n")
        }
    }

    private func fingerprint(for entries: [DictionaryEntry]) -> String {
        entries
            .map { "\($0.id.uuidString):\($0.phrase)" }
            .sorted()
            .joined(separator: "|")
    }
}
