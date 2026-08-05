import Foundation

private enum NumericEvaluationConstants {
    static let minimumNonNumericTokenSimilarity = 0.72
}

extension DictionaryMatcher {
    func hasSufficientNumericAlignment(
        observedNormalized: String,
        observedNumericSourceTokens: [String?],
        candidate: CompiledEntry
    ) -> Bool {
        guard candidate.numericSourceTokens.contains(where: { $0 != nil }) else {
            return true
        }

        let observedTokens = observedNormalized.split(separator: " ").map(String.init)
        guard observedTokens.count == candidate.tokens.count,
              observedNumericSourceTokens.count == candidate.tokens.count,
              candidate.numericSourceTokens.count == candidate.tokens.count else {
            return false
        }

        var index = 0
        while index < candidate.tokens.count {
            let observedToken = observedTokens[index]
            let candidateToken = candidate.tokens[index]

            if let candidateNumericSource = candidate.numericSourceTokens[index] {
                var numericGroupEnd = index + 1
                while numericGroupEnd < candidate.numericSourceTokens.count,
                      candidate.numericSourceTokens[numericGroupEnd] == candidateNumericSource {
                    numericGroupEnd += 1
                }

                let observedGroupSources = observedNumericSourceTokens[index..<numericGroupEnd]
                if observedGroupSources.contains(where: { $0 != nil }) {
                    guard observedGroupSources.allSatisfy({ $0 == candidateNumericSource }) else {
                        return false
                    }
                } else {
                    let observedGroup = observedTokens[index..<numericGroupEnd].joined(separator: " ")
                    guard DictionaryNumericMatching.tokenVariants(for: candidateNumericSource)
                        .contains(observedGroup) else {
                        return false
                    }
                }

                index = numericGroupEnd
                continue
            }

            if observedNumericSourceTokens[index] != nil {
                guard numericTokenVariantsOverlap(observedToken, candidateToken) else {
                    return false
                }
                index += 1
                continue
            }

            guard !hasSingularPluralMismatch(
                observedToken: observedToken,
                candidateToken: candidateToken
            ) else {
                return false
            }

            let textSimilarity = scorer.similarity(lhs: observedToken, rhs: candidateToken)
            let observedPhonetic = encoder.scoringSignature(for: observedToken, lexicon: lexicon)
            let candidatePhonetic = encoder.scoringSignature(for: candidateToken, lexicon: lexicon)
            let phoneticSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)

            guard max(textSimilarity, phoneticSimilarity)
                >= NumericEvaluationConstants.minimumNonNumericTokenSimilarity else {
                return false
            }

            index += 1
        }

        return true
    }

    private func hasSingularPluralMismatch(observedToken: String, candidateToken: String) -> Bool {
        func singularStem(of token: String) -> String? {
            guard token.count > 3,
                  token.hasSuffix("s"),
                  !token.hasSuffix("ss"),
                  !token.hasSuffix("s'") else {
                return nil
            }
            return String(token.dropLast())
        }

        return singularStem(of: observedToken) == candidateToken
            || singularStem(of: candidateToken) == observedToken
    }

    private func numericTokenVariantsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let lhsVariants = Set(DictionaryNumericMatching.tokenVariants(for: lhs))
        let rhsVariants = Set(DictionaryNumericMatching.tokenVariants(for: rhs))
        return !lhsVariants.isDisjoint(with: rhsVariants)
    }
}
