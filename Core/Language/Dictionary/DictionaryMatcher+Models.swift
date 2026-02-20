import Foundation

extension DictionaryMatcher {
    struct Token {
        let raw: String
        let normalized: String
        let range: NSRange
        let phonetic: String
    }

    struct CompiledEntry {
        let phrase: String
        let normalizedPhrase: String
        let tokens: [String]
        let phoneticPhrase: String
    }

    struct Candidate {
        let entry: CompiledEntry
        let score: ReplacementScore
        let replacementSuffix: String
    }

    struct ProposedReplacement {
        let tokenStart: Int
        let tokenEndExclusive: Int
        let range: NSRange
        let replacement: String
        let score: Double
        let requiresPeerSupport: Bool

        init(
            tokenStart: Int,
            tokenEndExclusive: Int,
            range: NSRange,
            replacement: String,
            score: Double,
            requiresPeerSupport: Bool = false
        ) {
            self.tokenStart = tokenStart
            self.tokenEndExclusive = tokenEndExclusive
            self.range = range
            self.replacement = replacement
            self.score = score
            self.requiresPeerSupport = requiresPeerSupport
        }
    }

    struct JoinedObservedForm {
        let normalized: String
        let singularizedSecondToken: Bool
        let replacementSuffix: String
    }
}
