import Foundation

extension DictionaryMatcher {
    func shouldRejectMismatchedSpelledUppercaseSequence(
        window: [Token],
        candidate: CompiledEntry
    ) -> Bool {
        let observedCollapsed = window.map(\.normalized).joined()
        let candidateCollapsed = candidate.tokens.joined()
        guard observedCollapsed != candidateCollapsed else { return false }

        let requiredSequences = uppercaseLetterSequences(in: candidate.phrase)
        guard !requiredSequences.isEmpty else { return false }

        let observedSequences = observedSpelledSequences(in: window)
        return requiredSequences.contains { sequence in
            let normalizedSequence = DictionaryTextNormalization.normalizedToken(sequence)
            if observedSequences.contains(normalizedSequence) {
                return false
            }

            let requiredPhonetic = encoder.fallbackSignature(for: normalizedSequence)
            return !observedSequences.contains { observedSequence in
                encoder.fallbackSignature(for: observedSequence) == requiredPhonetic
            }
        }
    }

    private func observedSpelledSequences(in window: [Token]) -> Set<String> {
        var sequences = Set(window.map(\.normalized))

        for token in window {
            for sequence in uppercaseLetterSequences(in: token.raw) {
                sequences.insert(DictionaryTextNormalization.normalizedToken(sequence))
            }
        }

        var singleLetterRun = ""
        for token in window {
            if token.normalized.count == 1 {
                singleLetterRun += token.normalized
            } else {
                if singleLetterRun.count > 1 {
                    sequences.insert(singleLetterRun)
                }
                singleLetterRun = ""
            }
        }
        if singleLetterRun.count > 1 {
            sequences.insert(singleLetterRun)
        }

        return sequences
    }

    private func uppercaseLetterSequences(in phrase: String) -> [String] {
        let scalars = Array(phrase.unicodeScalars)
        var sequences: [String] = []
        var index = scalars.startIndex

        while index < scalars.endIndex {
            guard isUppercaseLetter(scalars[index]) else {
                index += 1
                continue
            }

            let runStart = index
            while index < scalars.endIndex, isUppercaseLetter(scalars[index]) {
                index += 1
            }

            var run = Array(scalars[runStart..<index])
            if index < scalars.endIndex,
               scalars[index].properties.isLowercase,
               !run.isEmpty {
                run.removeLast()
            }

            guard run.count > 1 else { continue }
            sequences.append(run.map(String.init).joined())
        }

        return sequences
    }

    private func isUppercaseLetter(_ scalar: Unicode.Scalar) -> Bool {
        scalar.properties.isAlphabetic && scalar.properties.isUppercase
    }
}
