import Foundation

@MainActor
final class TranscriptionPostProcessor {
    private let enablePhoneticMatcher = true
    private let vocabularyNormalizer = CustomVocabularyNormalizer()
    private let dictionaryMatcher = DictionaryMatcher()
    private var dictionaryFingerprint = ""

    func updateDictionaryEntries(_ entries: [DictionaryEntry]) {
        let fingerprint = fingerprint(for: entries)
        guard fingerprint != dictionaryFingerprint else { return }
        dictionaryFingerprint = fingerprint
        dictionaryMatcher.rebuildIndex(entries: entries)
    }

    func process(_ text: String, dictionaryEntries: [DictionaryEntry]) -> String {
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

        return normalized
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func fingerprint(for entries: [DictionaryEntry]) -> String {
        entries
            .map { "\($0.id.uuidString):\($0.phrase)" }
            .sorted()
            .joined(separator: "|")
    }
}
