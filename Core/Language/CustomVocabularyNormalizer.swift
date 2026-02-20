import Foundation

@MainActor
struct CustomVocabularyNormalizer {
    private struct Candidate {
        let phrase: String
        let comparable: String
    }

    private struct Token {
        let range: NSRange
        let comparable: String
    }

    func normalize(_ text: String, with entries: [DictionaryEntry]) -> String {
        guard !text.isEmpty else { return "" }

        let candidates = entries
            .map { Candidate(phrase: $0.phrase, comparable: comparableKey(for: $0.phrase)) }
            .filter { !$0.comparable.isEmpty }

        guard !candidates.isEmpty else { return text }

        var output = applyExactPhraseReplacement(text, candidates: candidates)
        output = applyFuzzySingleWordReplacement(output, candidates: candidates)
        return output
    }

    private func applyExactPhraseReplacement(_ text: String, candidates: [Candidate]) -> String {
        var output = text
        let sorted = candidates.sorted { $0.phrase.count > $1.phrase.count }

        for candidate in sorted {
            let escaped = NSRegularExpression.escapedPattern(for: candidate.phrase)
                .replacingOccurrences(of: "\\ ", with: "\\s+")
            let pattern = "(?i)\\b\(escaped)\\b"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }

            let range = NSRange(location: 0, length: output.utf16.count)
            output = regex.stringByReplacingMatches(in: output, options: [], range: range, withTemplate: candidate.phrase)
        }

        return output
    }

    private func applyFuzzySingleWordReplacement(_ text: String, candidates: [Candidate]) -> String {
        let singleWordCandidates = candidates.filter { !$0.phrase.contains(" ") }
        guard !singleWordCandidates.isEmpty else { return text }

        let nsText = text as NSString
        let regex = try? NSRegularExpression(pattern: "\\b[\\p{L}\\p{N}']+\\b", options: [])
        let matches = regex?.matches(in: text, options: [], range: NSRange(location: 0, length: nsText.length)) ?? []

        let tokens: [Token] = matches.map {
            let raw = nsText.substring(with: $0.range)
            return Token(range: $0.range, comparable: comparableKey(for: raw))
        }

        guard !tokens.isEmpty else { return text }

        var replacements: [(NSRange, String)] = []

        for token in tokens {
            guard !token.comparable.isEmpty else { continue }

            var best: (candidate: Candidate, score: Double)?
            var secondBestScore = 0.0

            for candidate in singleWordCandidates {
                let score = similarity(lhs: token.comparable, rhs: candidate.comparable)

                if let currentBest = best {
                    if score > currentBest.score {
                        secondBestScore = currentBest.score
                        best = (candidate, score)
                    } else if score > secondBestScore {
                        secondBestScore = score
                    }
                } else {
                    best = (candidate, score)
                }
            }

            guard let best else { continue }
            guard shouldReplace(tokenComparable: token.comparable, bestScore: best.score, secondBestScore: secondBestScore) else {
                continue
            }

            replacements.append((token.range, best.candidate.phrase))
        }

        if replacements.isEmpty {
            return text
        }

        var output = text
        for replacement in replacements.reversed() {
            guard let swiftRange = Range(replacement.0, in: output) else { continue }
            output.replaceSubrange(swiftRange, with: replacement.1)
        }

        return output
    }

    private func shouldReplace(tokenComparable: String, bestScore: Double, secondBestScore: Double) -> Bool {
        let minScore = minimumScore(for: tokenComparable.count)
        guard bestScore >= minScore else { return false }

        let ambiguityMargin = 0.08
        if secondBestScore > 0 && (bestScore - secondBestScore) < ambiguityMargin {
            return false
        }

        return true
    }

    private func minimumScore(for length: Int) -> Double {
        switch length {
        case 0...4: return 0.80
        case 5...7: return 0.74
        case 8...12: return 0.68
        default: return 0.64
        }
    }

    private func comparableKey(for value: String) -> String {
        let folded = value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        return folded.replacingOccurrences(of: "[^a-z0-9]", with: "", options: .regularExpression)
    }

    private func similarity(lhs: String, rhs: String) -> Double {
        guard !lhs.isEmpty && !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }

        let distance = levenshtein(lhs, rhs)
        let maxCount = max(lhs.count, rhs.count)
        guard maxCount > 0 else { return 0 }
        return max(0, 1 - (Double(distance) / Double(maxCount)))
    }

    private func levenshtein(_ lhs: String, _ rhs: String) -> Int {
        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)

        if lhsChars.isEmpty { return rhsChars.count }
        if rhsChars.isEmpty { return lhsChars.count }

        var previous = Array(0...rhsChars.count)
        var current = Array(repeating: 0, count: rhsChars.count + 1)

        for (i, lhsChar) in lhsChars.enumerated() {
            current[0] = i + 1
            for (j, rhsChar) in rhsChars.enumerated() {
                let substitutionCost = lhsChar == rhsChar ? 0 : 1
                current[j + 1] = min(
                    current[j] + 1,
                    previous[j + 1] + 1,
                    previous[j] + substitutionCost
                )
            }
            swap(&previous, &current)
        }

        return previous[rhsChars.count]
    }
}
