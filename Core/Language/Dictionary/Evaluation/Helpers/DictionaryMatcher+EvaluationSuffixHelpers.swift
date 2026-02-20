import Foundation

extension DictionaryMatcher {
    func observedFormsForWindow(
        tokenCount: Int,
        window: [Token],
        observedNormalized: String,
        observedPhonetic: String
    ) -> [(normalized: String, phonetic: String, replacementSuffix: String)] {
        guard tokenCount == 1 || tokenCount == 2 else {
            return [(normalized: observedNormalized, phonetic: observedPhonetic, replacementSuffix: "")]
        }

        var forms: [(normalized: String, phonetic: String, replacementSuffix: String)] = [
            (normalized: observedNormalized, phonetic: observedPhonetic, replacementSuffix: "")
        ]
        var seen = Set<String>()
        seen.insert("\(observedNormalized)|")

        if tokenCount == 1 {
            let observedRawToken = window.first?.raw ?? observedNormalized
            if observedNormalized.hasSuffix("'s"), observedNormalized.count > 3 {
                let stem = String(observedNormalized.dropLast(2))
                if stem.count >= 3 {
                    let key = "\(stem)|'s"
                    if seen.insert(key).inserted {
                        forms.append((
                            normalized: stem,
                            phonetic: encoder.scoringSignature(for: stem, lexicon: lexicon),
                            replacementSuffix: "'s"
                        ))
                    }
                }
            } else if observedNormalized.hasSuffix("s"),
                      !observedNormalized.hasSuffix("s'"),
                      observedNormalized.count > 3 {
                let stem = String(observedNormalized.dropLast())
                if stem.count >= 3 {
                    let pluralKey = "\(stem)|s"
                    if seen.insert(pluralKey).inserted {
                        forms.append((
                            normalized: stem,
                            phonetic: encoder.scoringSignature(for: stem, lexicon: lexicon),
                            replacementSuffix: "s"
                        ))
                    }

                    // Preserve implicit possessive recovery for proper-name-like tokens.
                    let startsUppercase = observedRawToken.unicodeScalars.first?.properties.isUppercase == true
                    if startsUppercase {
                        let possessiveKey = "\(stem)|'s"
                        if seen.insert(possessiveKey).inserted {
                            forms.append((
                                normalized: stem,
                                phonetic: encoder.scoringSignature(for: stem, lexicon: lexicon),
                                replacementSuffix: "'s"
                            ))
                        }
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
                let key = "\(normalized)|'s"
                if seen.insert(key).inserted {
                    forms.append((
                        normalized: normalized,
                        phonetic: encoder.scoringPhraseSignature(for: [first, stem], lexicon: lexicon),
                        replacementSuffix: "'s"
                    ))
                }
            }
        } else if second.hasSuffix("s"),
                  !second.hasSuffix("s'"),
                  second.count > minimumSplitTokenLength {
            // Whisper often emits possessive names without apostrophes: "Especitos".
            let stem = String(second.dropLast())
            if stem.count >= minimumSplitTokenLength {
                let normalized = "\(first) \(stem)"
                let key = "\(normalized)|'s"
                if seen.insert(key).inserted {
                    forms.append((
                        normalized: normalized,
                        phonetic: encoder.scoringPhraseSignature(for: [first, stem], lexicon: lexicon),
                        replacementSuffix: "'s"
                    ))
                }
            }
        }

        return forms
    }

    func baseTokenForCommonWordGuard(_ token: String) -> String {
        if token.hasSuffix("'s"), token.count > 3 {
            return String(token.dropLast(2))
        }

        return token
    }

    func shouldInferPossessiveSuffix(
        observed: String,
        observedPhonetic: String,
        candidate: String,
        nextToken: Token?
    ) -> Bool {
        guard nextToken != nil else { return false }
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

        return possessiveSimilarity >= baseSimilarity + 0.08
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
