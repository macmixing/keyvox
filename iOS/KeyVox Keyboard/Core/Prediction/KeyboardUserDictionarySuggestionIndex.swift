import Foundation

struct KeyboardUserDictionarySuggestionIndex: Sendable {
    private struct Candidate: Sendable {
        let phrase: String
        let normalized: String
    }

    static let empty = KeyboardUserDictionarySuggestionIndex(phrases: [])

    private let candidatesByLength: [Int: [Candidate]]

    init(phrases: [String]) {
        let candidates = phrases.compactMap { phrase -> Candidate? in
            guard phrase.isEmpty == false,
                  phrase.contains(where: \.isWhitespace) == false else {
                return nil
            }
            return Candidate(phrase: phrase, normalized: Self.normalize(phrase))
        }
        candidatesByLength = Dictionary(grouping: candidates, by: { $0.normalized.count })
    }

    func preferredSuggestion(for typedWord: String) -> String? {
        let normalizedWord = Self.normalize(typedWord)
        guard normalizedWord.isEmpty == false else { return nil }

        if let exact = candidatesByLength[normalizedWord.count]?.first(where: {
            $0.normalized == normalizedWord && $0.phrase != typedWord
        }) {
            return exact.phrase
        }

        let maximumDistance = Self.maximumDistance(for: normalizedWord.count)
        guard maximumDistance > 0 else { return nil }
        var matches: [(candidate: Candidate, distance: Int)] = []
        let minimumLength = max(1, normalizedWord.count - maximumDistance)
        let maximumLength = normalizedWord.count + maximumDistance
        for length in minimumLength...maximumLength {
            for candidate in candidatesByLength[length] ?? [] {
                let distance = Self.editDistance(
                    normalizedWord,
                    candidate.normalized,
                    maximumDistance: maximumDistance
                )
                guard distance > 0, distance <= maximumDistance else { continue }
                matches.append((candidate, distance))
            }
        }
        matches.sort { left, right in
            if left.distance != right.distance { return left.distance < right.distance }
            return left.candidate.phrase < right.candidate.phrase
        }
        guard let best = matches.first else { return nil }
        if let competing = matches.dropFirst().first,
           competing.distance == best.distance,
           competing.candidate.normalized != best.candidate.normalized {
            return nil
        }
        return best.candidate.phrase
    }

    private static func maximumDistance(for length: Int) -> Int {
        if length <= 2 { return 0 }
        if length <= 7 { return 1 }
        return 2
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .replacingOccurrences(of: "’", with: "'")
    }

    private static func editDistance(
        _ left: String,
        _ right: String,
        maximumDistance: Int
    ) -> Int {
        let leftCharacters = Array(left)
        let rightCharacters = Array(right)
        let outsideBand = maximumDistance + 1
        guard abs(leftCharacters.count - rightCharacters.count) <= maximumDistance else {
            return outsideBand
        }
        var previousPrevious = Array(0...rightCharacters.count)
        var previous = previousPrevious
        var current = previousPrevious
        for leftIndex in 1...leftCharacters.count {
            current[0] = leftIndex
            var rowMinimum = current[0]
            for rightIndex in 1...rightCharacters.count {
                let substitution = previous[rightIndex - 1]
                    + (leftCharacters[leftIndex - 1] == rightCharacters[rightIndex - 1] ? 0 : 1)
                current[rightIndex] = min(
                    previous[rightIndex] + 1,
                    current[rightIndex - 1] + 1,
                    substitution
                )
                if leftIndex > 1,
                   rightIndex > 1,
                   leftCharacters[leftIndex - 1] == rightCharacters[rightIndex - 2],
                   leftCharacters[leftIndex - 2] == rightCharacters[rightIndex - 1] {
                    current[rightIndex] = min(
                        current[rightIndex],
                        previousPrevious[rightIndex - 2] + 1
                    )
                }
                rowMinimum = min(rowMinimum, current[rightIndex])
            }
            if rowMinimum > maximumDistance { return outsideBand }
            previousPrevious = previous
            previous = current
        }
        return min(previous[rightCharacters.count], outsideBand)
    }
}
