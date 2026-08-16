import Foundation

private enum EvaluationSuffixConstants {
    static let minimumStemLength = 3
    static let possessiveSimilarityImprovementMinimum = 0.08
}

extension DictionaryMatcher {
    func observedFormsForWindow(
        tokenCount: Int,
        window: [Token],
        observedNormalized: String,
        observedPhonetic: String
    ) -> [(normalized: String, phonetic: String, replacementSuffix: String, numericSourceTokens: [String?])] {
        func numericSourceTokens(for normalized: String) -> [String?] {
            let tokens = normalized.split(separator: " ").map(String.init)
            return DictionaryNumericMatching.phraseVariants(for: tokens)
                .first(where: { $0.normalized == normalized })?
                .numericSourceTokens
                ?? Array(repeating: nil, count: tokens.count)
        }

        guard tokenCount == 1 || tokenCount == 2 else {
            return [(
                normalized: observedNormalized,
                phonetic: observedPhonetic,
                replacementSuffix: "",
                numericSourceTokens: numericSourceTokens(for: observedNormalized)
            )]
        }

        var seen = Set<String>()
        var forms: [(normalized: String, phonetic: String, replacementSuffix: String, numericSourceTokens: [String?])] = []

        func appendForm(
            normalized: String,
            phonetic: String,
            replacementSuffix: String,
            numericSourceTokens: [String?]
        ) {
            let key = "\(normalized)|\(replacementSuffix)"
            guard seen.insert(key).inserted else { return }
            forms.append((
                normalized: normalized,
                phonetic: phonetic,
                replacementSuffix: replacementSuffix,
                numericSourceTokens: numericSourceTokens
            ))
        }

        appendForm(
            normalized: observedNormalized,
            phonetic: observedPhonetic,
            replacementSuffix: "",
            numericSourceTokens: numericSourceTokens(for: observedNormalized)
        )

        for numericVariant in DictionaryNumericMatching.phraseVariants(for: window.map(\.normalized))
        where numericVariant.normalized != observedNormalized
            && numericVariant.tokens.count == tokenCount {
            appendForm(
                normalized: numericVariant.normalized,
                phonetic: encoder.scoringPhraseSignature(for: numericVariant.tokens, lexicon: lexicon),
                replacementSuffix: "",
                numericSourceTokens: numericVariant.numericSourceTokens
            )
        }

        if tokenCount == 1 {
            let observedRawToken = window.first?.raw ?? observedNormalized
            if observedNormalized.hasSuffix("'s"), observedNormalized.count > 3 {
                let stem = String(observedNormalized.dropLast(2))
                if stem.count >= EvaluationSuffixConstants.minimumStemLength {
                    appendForm(
                        normalized: stem,
                        phonetic: encoder.scoringSignature(for: stem, lexicon: lexicon),
                        replacementSuffix: "'s",
                        numericSourceTokens: numericSourceTokens(for: stem)
                    )
                }
            } else if observedNormalized.hasSuffix("s"),
                      !observedNormalized.hasSuffix("ss"),
                      !observedNormalized.hasSuffix("s'"),
                      observedNormalized.count > 3 {
                let stem = String(observedNormalized.dropLast())
                if stem.count >= EvaluationSuffixConstants.minimumStemLength {
                    appendForm(
                        normalized: stem,
                        phonetic: encoder.scoringSignature(for: stem, lexicon: lexicon),
                        replacementSuffix: "s",
                        numericSourceTokens: numericSourceTokens(for: stem)
                    )

                    // Preserve implicit possessive recovery for proper-name-like tokens.
                    let startsUppercase = observedRawToken.unicodeScalars.first?.properties.isUppercase == true
                    if startsUppercase {
                        appendForm(
                            normalized: stem,
                            phonetic: encoder.scoringSignature(for: stem, lexicon: lexicon),
                            replacementSuffix: "'s",
                            numericSourceTokens: numericSourceTokens(for: stem)
                        )
                    }
                }
            }
            return forms
        }

        guard tokenCount == 2, window.count == 2 else { return forms }
        let first = window[0].normalized
        let second = window[1].normalized

        if second.hasSuffix("'s"), second.count > minimumSplitTokenLength {
            let stem = String(second.dropLast(2))
            if stem.count >= minimumSplitTokenLength {
                let normalized = "\(first) \(stem)"
                appendForm(
                    normalized: normalized,
                    phonetic: encoder.scoringPhraseSignature(for: [first, stem], lexicon: lexicon),
                    replacementSuffix: "'s",
                    numericSourceTokens: numericSourceTokens(for: normalized)
                )
            }
        } else if second.hasSuffix("s"),
                  !second.hasSuffix("ss"),
                  !second.hasSuffix("s'"),
                  second.count > minimumSplitTokenLength {
            // Whisper often emits possessive names without apostrophes: "Especitos".
            let stem = String(second.dropLast())
            if stem.count >= minimumSplitTokenLength {
                let normalized = "\(first) \(stem)"
                appendForm(
                    normalized: normalized,
                    phonetic: encoder.scoringPhraseSignature(for: [first, stem], lexicon: lexicon),
                    replacementSuffix: "'s",
                    numericSourceTokens: numericSourceTokens(for: normalized)
                )
            }
        }

        return forms
    }

    func baseTokenForCommonWordGuard(_ token: String) -> String {
        if token.hasSuffix("'s"), token.count > 3 {
            return String(token.dropLast(2))
        }

        if token.hasSuffix("s"), !token.hasSuffix("ss"), !token.hasSuffix("s'"), token.count > 3 {
            let singularStem = String(token.dropLast(1))
            if lexicon.isCommonWord(singularStem) {
                return singularStem
            }
        }

        return token
    }

    func shouldInferPossessiveSuffix(
        observed: String,
        observedPhonetic: String,
        candidate: String,
        nextToken: Token?,
        hasCandidateRelativeTrailingEvidence: Bool = false
    ) -> Bool {
        guard let nextToken,
              nextToken.lexicalClass != .verb,
              nextToken.lexicalClass != .conjunction else {
            return false
        }
        if hasCandidateRelativeTrailingEvidence {
            return true
        }
        guard !candidate.hasSuffix("s") else { return false }
        guard observed.hasSuffix("s") || observed.hasSuffix("x") || observed.hasSuffix("z") else { return false }

        let candidatePhonetic = encoder.scoringSignature(for: candidate, lexicon: lexicon)
        let candidateWithS = "\(candidate)s"
        let candidateWithSPhonetic = encoder.scoringSignature(for: candidateWithS, lexicon: lexicon)
        let observedFallback = encoder.fallbackSignature(for: observed)
        let candidateFallback = encoder.fallbackSignature(for: candidate)
        let candidateWithSFallback = encoder.fallbackSignature(for: candidateWithS)

        let baseSimilarity = max(
            scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic),
            scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        )
        let possessiveSimilarity = max(
            scorer.similarity(lhs: observedPhonetic, rhs: candidateWithSPhonetic),
            scorer.similarity(lhs: observedFallback, rhs: candidateWithSFallback)
        )

        return possessiveSimilarity >= baseSimilarity + EvaluationSuffixConstants.possessiveSimilarityImprovementMinimum
    }

    func possessiveBonus(for replacementSuffix: String) -> Double {
        replacementSuffix == "'s" ? possessiveStemScoreBoost : 0
    }

    func normalizedPossessiveStem(for token: String) -> (stem: String, suffix: String) {
        if token.hasSuffix("'s"), token.count > 3 {
            return (String(token.dropLast(2)), "'s")
        }

        if token.hasSuffix("s"), !token.hasSuffix("s'"), token.count > 3 {
            return (String(token.dropLast(1)), "'s")
        }

        return (token, "")
    }

    func resolvedPossessiveSuffix(basePhrase: String, desiredSuffix: String) -> String {
        guard desiredSuffix == "'s" else { return "" }
        return basePhrase.lowercased().hasSuffix("'s") ? "" : "'s"
    }
}
