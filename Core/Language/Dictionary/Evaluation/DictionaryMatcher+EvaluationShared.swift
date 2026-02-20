import Foundation

extension DictionaryMatcher {
    func shouldConsumeSplitTailToken(
        window: [Token],
        candidate: CompiledEntry,
        nextToken: Token?
    ) -> Bool {
        guard window.count == candidate.tokens.count, window.count > 1 else { return false }
        guard let nextToken else { return false }

        // Guard a specific false-positive shape where Whisper splits the end of the
        // final dictionary token into a separate trailing token (e.g. "pinup ca").
        let sharedPrefixCount = window.count - 1
        for index in 0..<sharedPrefixCount where window[index].normalized != candidate.tokens[index] {
            return false
        }

        guard let observedLast = window.last?.normalized, let candidateLast = candidate.tokens.last else {
            return false
        }
        guard candidateLast.count > observedLast.count, candidateLast.hasPrefix(observedLast) else {
            return false
        }

        let trailingSuffix = String(candidateLast.dropFirst(observedLast.count))
        guard trailingSuffix.count >= 2 else { return false }
        return nextToken.normalized == trailingSuffix
    }

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
                            phonetic: encoder.signature(for: stem, lexicon: lexicon),
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
                            phonetic: encoder.signature(for: stem, lexicon: lexicon),
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
                                phonetic: encoder.signature(for: stem, lexicon: lexicon),
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
                        phonetic: encoder.phraseSignature(for: [first, stem], lexicon: lexicon),
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
                        phonetic: encoder.phraseSignature(for: [first, stem], lexicon: lexicon),
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

    func isStylizedSingleTokenEntry(_ entry: CompiledEntry) -> Bool {
        guard entry.tokens.count == 1 else { return false }
        guard !entry.phrase.contains(" ") else { return false }
        let firstScalar = entry.phrase.unicodeScalars.first
        return entry.phrase.unicodeScalars.contains { scalar in
            guard scalar.properties.isUppercase else { return false }
            return scalar != firstScalar
        }
    }

    func hasStrongStylizedTextEvidence(
        observed: String,
        candidate: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= 0.83 else { return false }
        guard observed.unicodeScalars.first == candidate.unicodeScalars.first else { return false }
        guard observed.unicodeScalars.last == candidate.unicodeScalars.last else { return false }
        return true
    }

    func stylizedFallbackPhoneticSimilarity(
        tokenCount: Int,
        observedNormalized: String,
        observedPhonetic: String,
        candidate: CompiledEntry
    ) -> Double {
        guard tokenCount == 1, candidate.tokens.count == 1 else { return 0 }
        guard isStylizedSingleTokenEntry(candidate) else { return 0 }
        guard observedNormalized.count >= 4, candidate.tokens[0].count >= 5 else { return 0 }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidate.tokens[0])) else { return 0 }

        let observedFallback = encoder.fallbackSignature(for: observedNormalized)
        let candidateFallback = encoder.fallbackSignature(for: candidate.tokens[0])
        guard !observedFallback.isEmpty, !candidateFallback.isEmpty else { return 0 }

        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidate.phoneticPhrase)
        return max(fallbackSimilarity, runtimeSimilarity)
    }

    func hasStrongStylizedFallbackPhoneticEvidence(
        observed: String,
        candidate: String,
        observedPhonetic: String,
        candidatePhonetic: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= 0.22 else { return false }
        let observedFallback = encoder.fallbackSignature(for: observed)
        let candidateFallback = encoder.fallbackSignature(for: candidate)
        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
        return max(fallbackSimilarity, runtimeSimilarity) >= 0.88
    }

    func hasModerateStylizedFallbackPhoneticEvidence(
        observed: String,
        candidate: String,
        observedPhonetic: String,
        candidatePhonetic: String,
        textSimilarity: Double
    ) -> Bool {
        guard textSimilarity >= 0.42 else { return false }
        guard let observedFirst = observed.first?.lowercased(),
              let candidateFirst = candidate.first?.lowercased(),
              observedFirst == candidateFirst else { return false }
        let observedFallback = encoder.fallbackSignature(for: observed)
        let candidateFallback = encoder.fallbackSignature(for: candidate)
        let fallbackSimilarity = scorer.similarity(lhs: observedFallback, rhs: candidateFallback)
        let runtimeSimilarity = scorer.similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
        return max(fallbackSimilarity, runtimeSimilarity) >= 0.66
    }

    func allowStylizedFallbackForCommonObservedToken(
        token: Token,
        tokenIndex: Int,
        totalTokens: Int
    ) -> Bool {
        guard let first = token.raw.first else { return false }
        guard String(first).uppercased() == String(first) else { return false }
        if token.raw.dropFirst().contains(where: { String($0).uppercased() == String($0) }) {
            return true
        }

        // Avoid sentence-start capitalization false positives in prose.
        if tokenIndex == 0, totalTokens > 1 {
            return false
        }

        return true
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

        let candidatePhonetic = encoder.signature(for: candidate, lexicon: lexicon)
        let candidateWithS = "\(candidate)s"
        let candidateWithSPhonetic = encoder.signature(for: candidateWithS, lexicon: lexicon)
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

    func hasStrongAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
        guard window.count == 2, candidate.tokens.count == 2 else { return false }
        let observedFirst = window[0].normalized
        let observedSecond = window[1].normalized
        let candidateFirst = candidate.tokens[0]
        let candidateSecond = candidate.tokens[1]

        guard observedFirst == candidateFirst else { return false }
        guard observedSecond.count >= 5, candidateSecond.count >= 5 else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }

        let candidateSecondPhonetic = encoder.signature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        return secondTextSimilarity >= 0.70 || secondPhoneticSimilarity >= 0.72
    }

    func hasModerateAnchoredTwoTokenEvidence(window: [Token], candidate: CompiledEntry) -> Bool {
        guard window.count == 2, candidate.tokens.count == 2 else { return false }
        let observedFirst = window[0].normalized
        let observedSecond = window[1].normalized
        let candidateFirst = candidate.tokens[0]
        let candidateSecond = candidate.tokens[1]

        guard observedFirst == candidateFirst else { return false }
        guard observedSecond.count >= 6, candidateSecond.count >= 6 else { return false }
        guard !lexicon.isCommonWord(baseTokenForCommonWordGuard(candidateSecond)) else { return false }
        guard observedSecond.first == candidateSecond.first else { return false }
        guard observedSecond.last == candidateSecond.last else { return false }

        let candidateSecondPhonetic = encoder.signature(for: candidateSecond, lexicon: lexicon)
        let secondTextSimilarity = scorer.similarity(lhs: observedSecond, rhs: candidateSecond)
        let secondPhoneticSimilarity = scorer.similarity(lhs: window[1].phonetic, rhs: candidateSecondPhonetic)

        // Favor text shape for this fallback because runtime lexicon coverage can
        // under-represent proper-name variants. Keep phonetic as an alternate path.
        return secondTextSimilarity >= 0.60 || secondPhoneticSimilarity >= 0.68
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

    func tokenAlignmentBoost(window: [Token], candidate: CompiledEntry) -> Double {
        guard window.count == candidate.tokens.count else { return 0 }
        guard !window.isEmpty else { return 0 }

        let candidatePhonetics = candidate.tokens.map { encoder.signature(for: $0, lexicon: lexicon) }
        var exactMatches = 0
        var strongMatches = 0
        var firstTokenExact = false

        for index in window.indices {
            let observedToken = window[index]
            let candidateToken = candidate.tokens[index]

            let textScore = scorer.similarity(lhs: observedToken.normalized, rhs: candidateToken)
            let phoneticScore = scorer.similarity(lhs: observedToken.phonetic, rhs: candidatePhonetics[index])
            let blendedScore = (0.55 * textScore) + (0.45 * phoneticScore)

            if textScore == 1.0 {
                exactMatches += 1
                if index == 0 {
                    firstTokenExact = true
                }
            }

            if textScore >= 0.78 || phoneticScore >= 0.78 || blendedScore >= 0.78 {
                strongMatches += 1
            }
        }

        // Name-like two-token phrases: "Dom Espicito" -> "Dom Esposito"
        if window.count == 2, firstTokenExact {
            let textTail = scorer.similarity(lhs: window[1].normalized, rhs: candidate.tokens[1])
            let phoneticTail = scorer.similarity(lhs: window[1].phonetic, rhs: candidatePhonetics[1])
            if textTail >= 0.70 || phoneticTail >= 0.72 {
                return 0.12
            }
            if textTail >= 0.60 || phoneticTail >= 0.68 {
                return 0.08
            }
        }

        if firstTokenExact && strongMatches == window.count {
            return 0.08
        }

        if exactMatches >= 1 && strongMatches == window.count {
            return 0.06
        }

        if strongMatches == window.count {
            return 0.04
        }

        return 0
    }
}
