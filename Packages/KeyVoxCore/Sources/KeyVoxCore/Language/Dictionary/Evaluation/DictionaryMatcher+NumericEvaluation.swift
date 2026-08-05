import Foundation

private enum NumericEvaluationConstants {
    static let minimumNonNumericTokenSimilarity = 0.72
}

extension DictionaryMatcher {
    func hasSufficientNumericAlignment(
        observedNormalized: String,
        candidate: CompiledEntry
    ) -> Bool {
        guard candidate.tokens.contains(where: DictionaryNumericMatching.isNumericToken) else {
            return true
        }

        let observedTokens = observedNormalized.split(separator: " ").map(String.init)
        guard observedTokens.count == candidate.tokens.count else {
            return true
        }

        for index in candidate.tokens.indices {
            let observedToken = observedTokens[index]
            let candidateToken = candidate.tokens[index]
            let observedIsNumeric = DictionaryNumericMatching.isNumericToken(observedToken)
            let candidateIsNumeric = DictionaryNumericMatching.isNumericToken(candidateToken)

            if observedIsNumeric || candidateIsNumeric {
                guard numericTokenVariantsOverlap(observedToken, candidateToken) else {
                    return false
                }
                continue
            }

            let textSimilarity = scorer.similarity(lhs: observedToken, rhs: candidateToken)
            let observedPhonetic = encoder.scoringSignature(for: observedToken, lexicon: lexicon)
            let candidatePhonetic = encoder.scoringSignature(for: candidateToken, lexicon: lexicon)
            let phoneticSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)

            guard max(textSimilarity, phoneticSimilarity)
                >= NumericEvaluationConstants.minimumNonNumericTokenSimilarity else {
                return false
            }
        }

        return true
    }

    private func numericTokenVariantsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let lhsVariants = Set(DictionaryNumericMatching.tokenVariants(for: lhs))
        let rhsVariants = Set(DictionaryNumericMatching.tokenVariants(for: rhs))
        return !lhsVariants.isDisjoint(with: rhsVariants)
    }
}
