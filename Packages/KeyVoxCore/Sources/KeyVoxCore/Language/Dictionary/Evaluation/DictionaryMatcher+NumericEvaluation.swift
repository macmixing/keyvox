import Foundation

private enum NumericEvaluationConstants {
    static let minimumNonNumericTokenSimilarity = 0.72
}

extension DictionaryMatcher {
    func hasSufficientNumericAlignment(
        observedNormalized: String,
        observedNumericSourceTokens: [String?],
        observedWindow: [Token],
        nextToken: Token?,
        candidate: CompiledEntry
    ) -> Bool {
        guard candidate.numericSourceTokens.contains(where: { $0 != nil }) else {
            return hasMatchingObservedNumberTokens(
                observedNormalized: observedNormalized,
                observedWindow: observedWindow,
                nextToken: nextToken,
                candidateTokens: candidate.tokens
            )
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

    // A number never becomes a different number. It stands in for an entry word only as a cardinal that does
    // not count what follows: an ordinal, or a plural in or right after the window, keeps the number as spoken.
    private func hasMatchingObservedNumberTokens(
        observedNormalized: String,
        observedWindow: [Token],
        nextToken: Token?,
        candidateTokens: [String]
    ) -> Bool {
        let observedTokens = observedNormalized.split(separator: " ").map(String.init)
        guard observedTokens.count == candidateTokens.count else { return true }
        let sourceTokens = observedWindow.count == observedTokens.count
            ? observedWindow.map(\.normalized)
            : observedTokens

        var replacesNumberWithWord = false
        for (index, (observed, candidate)) in zip(observedTokens, candidateTokens).enumerated()
        where DictionaryNumericMatching.isNumberToken(observed) {
            guard !numericTokenVariantsOverlap(observed, candidate) else { continue }
            guard !DictionaryNumericMatching.isNumberToken(candidate) else { return false }
            if DictionaryNumericMatching.isOrdinalNumericToken(sourceTokens[index]) {
                guard namesSameOrdinal(ordinalToken: sourceTokens[index], candidate: candidate) else { return false }
                continue
            }
            replacesNumberWithWord = true
        }
        guard replacesNumberWithWord else { return true }

        let countsWindowWord = zip(sourceTokens, candidateTokens).contains { observed, candidate in
            hasSingularPluralMismatch(observedToken: observed, candidateToken: candidate)
        }
        return !countsWindowWord && !isPluralNoun(nextToken)
    }

    private func namesSameOrdinal(ordinalToken: String, candidate: String) -> Bool {
        guard let cardinal = DictionaryNumericMatching.tokenVariants(for: ordinalToken).last,
              cardinal != ordinalToken,
              let cardinalPronunciation = lexicon.pronunciation(for: cardinal),
              let candidatePronunciation = lexicon.pronunciation(for: candidate) else {
            return false
        }
        return pronunciationNamesOrdinal(
            cardinalPronunciation: cardinalPronunciation,
            candidatePronunciation: candidatePronunciation
        )
    }

    // An entry word names an ordinal when its pronunciation adds only the ordinal ending to the cardinal's.
    func pronunciationNamesOrdinal(cardinalPronunciation: String, candidatePronunciation: String) -> Bool {
        let cardinalPhonemes = cardinalPronunciation.components(separatedBy: PronunciationLexicon.phonemeSeparator)
        let candidatePhonemes = candidatePronunciation.components(separatedBy: PronunciationLexicon.phonemeSeparator)
        return candidatePhonemes.count == cardinalPhonemes.count + StandardEvaluationPolicy.inflectionSuffixPhonemeCount
            && candidatePhonemes.starts(with: cardinalPhonemes)
    }

    private func isPluralNoun(_ token: Token?) -> Bool {
        guard let token,
              token.lexicalClass == .noun,
              let stem = singularStem(of: token.normalized) else {
            return false
        }
        return lexicon.pronunciation(for: stem) != nil
    }

    private func hasSingularPluralMismatch(observedToken: String, candidateToken: String) -> Bool {
        singularStem(of: observedToken) == candidateToken
            || singularStem(of: candidateToken) == observedToken
    }

    private func singularStem(of token: String) -> String? {
        guard token.count > 3,
              token.hasSuffix("s"),
              !token.hasSuffix("ss"),
              !token.hasSuffix("s'") else {
            return nil
        }
        return String(token.dropLast())
    }

    private func numericTokenVariantsOverlap(_ lhs: String, _ rhs: String) -> Bool {
        let lhsVariants = Set(DictionaryNumericMatching.tokenVariants(for: lhs))
        let rhsVariants = Set(DictionaryNumericMatching.tokenVariants(for: rhs))
        return !lhsVariants.isDisjoint(with: rhsVariants)
    }
}
