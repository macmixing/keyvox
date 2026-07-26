import Foundation
import KeyVoxCore

@MainActor
final class KeyboardUserDictionaryCorrectionController {
    private struct Match {
        let observed: String
        let replacement: String
        let distance: Int
    }

    private let store: KeyboardUserDictionaryStore
    private var indexedEntries: [DictionaryEntry] = []
    private var indexedCasingPhrases: [String] = []

    init(store: KeyboardUserDictionaryStore) {
        self.store = store
    }

    func reloadIfNeeded() {
        let entries = store.entries()
        guard entries != indexedEntries else { return }
        indexedEntries = entries
        indexedCasingPhrases = entries
            .map(\.phrase)
            .filter { $0.isEmpty == false }
            .sorted { $0.count > $1.count }
    }

    func correction(
        documentContextBeforeInput: String?
    ) -> KeyboardAutomaticCorrectionDecision? {
        let startedAt = ProcessInfo.processInfo.systemUptime
        reloadIfNeeded()
        guard indexedEntries.isEmpty == false,
              let context = documentContextBeforeInput,
              let suffix = Self.correctionContext(from: context) else {
            return nil
        }
        if let casingDecision = Self.exactCasingDecision(
            phrases: indexedCasingPhrases,
            context: suffix
        ) {
            KeyboardTypingDiagnostics.log("user_dictionary_casing_evaluation", fields: [
                "entry_count": indexedEntries.count,
                "context_length": suffix.count,
                "selected": true,
                "duration_ms": ((ProcessInfo.processInfo.systemUptime - startedAt) * 100_000)
                    .rounded() / 100,
            ])
            return casingDecision
        }

        let result = Self.bestTypoMatch(
            phrases: indexedCasingPhrases,
            context: suffix
        )
        KeyboardTypingDiagnostics.log("user_dictionary_evaluation", fields: [
            "entry_count": indexedEntries.count,
            "context_length": suffix.count,
            "attempted": indexedCasingPhrases.count,
            "selected": result != nil,
            "duration_ms": ((ProcessInfo.processInfo.systemUptime - startedAt) * 100_000)
                .rounded() / 100,
        ])
        guard let result else {
            return nil
        }
        return KeyboardAutomaticCorrectionDecision(
            original: result.observed,
            replacement: result.replacement,
            probability: 1
        )
    }

    private static func correctionContext(from context: String) -> String? {
        var start = context.endIndex
        var observedWordCount = 0
        var isInsideWord = false
        while start > context.startIndex, observedWordCount < 4 {
            let previous = context.index(before: start)
            let character = context[previous]
            let isWordCharacter = character.isLetter
                || character.isNumber
                || character == "'"
                || character == "’"
                || character == "@"
                || character == "."
                || character == "-"
            if isWordCharacter {
                isInsideWord = true
            } else if isInsideWord {
                observedWordCount += 1
                isInsideWord = false
                if observedWordCount == 4 {
                    break
                }
            }
            start = previous
        }
        while start < context.endIndex, context[start].isWhitespace {
            start = context.index(after: start)
        }
        guard start < context.endIndex else { return nil }
        return String(context[start...])
    }

    private static func exactCasingDecision(
        phrases: [String],
        context: String
    ) -> KeyboardAutomaticCorrectionDecision? {
        let trailingPunctuation = context.reversed().prefix { character in
            character.isPunctuation && character != "'" && character != "’"
        }
        let punctuationCount = trailingPunctuation.count
        let strippedPhraseEnd = context.index(
            context.endIndex,
            offsetBy: -punctuationCount
        )
        let phraseEnds = punctuationCount == 0
            ? [context.endIndex]
            : [context.endIndex, strippedPhraseEnd]

        for phraseEnd in phraseEnds {
            let phraseContext = context[..<phraseEnd]
            for phrase in phrases {
                guard phraseContext.count >= phrase.count else {
                    continue
                }
                let phraseStart = phraseContext.index(
                    phraseContext.endIndex,
                    offsetBy: -phrase.count
                )
                let observedPhrase = String(phraseContext[phraseStart...])
                guard observedPhrase != phrase,
                      observedPhrase.compare(
                        phrase,
                        options: [.caseInsensitive, .diacriticInsensitive]
                      ) == .orderedSame,
                      phraseStart == phraseContext.startIndex
                        || Self.isPhraseBoundary(phraseContext[phraseContext.index(before: phraseStart)]) else {
                    continue
                }

                let punctuation = String(context[phraseEnd...])
                return KeyboardAutomaticCorrectionDecision(
                    original: observedPhrase + punctuation,
                    replacement: phrase + punctuation,
                    probability: 1
                )
            }
        }
        return nil
    }

    private static func bestTypoMatch(
        phrases: [String],
        context: String
    ) -> Match? {
        let punctuationCount = context.reversed().prefix { character in
            character.isPunctuation
                && character != "'"
                && character != "’"
        }.count
        let phraseEnd = context.index(context.endIndex, offsetBy: -punctuationCount)
        let punctuation = String(context[phraseEnd...])
        let candidateContext = context[..<phraseEnd]
        let starts = suffixWordStarts(in: candidateContext)
        var matches: [Match] = []

        for phrase in phrases {
            let normalizedPhrase = normalize(phrase)
            let phraseWordCount = wordCount(in: normalizedPhrase)
            guard phraseWordCount > 0,
                  phraseWordCount <= starts.count else {
                continue
            }
            let start = starts[starts.count - phraseWordCount]
            let observed = String(candidateContext[start...])
            let normalizedObserved = normalize(observed)
            guard normalizedObserved != normalizedPhrase else { continue }
            let maximumDistance = maxDistance(for: normalizedPhrase.count)
            guard maximumDistance > 0 else { continue }
            let distance = editDistance(
                normalizedObserved,
                normalizedPhrase,
                maximumDistance: maximumDistance
            )
            guard distance > 0, distance <= maximumDistance else { continue }
            matches.append(
                Match(
                    observed: observed + punctuation,
                    replacement: phrase + punctuation,
                    distance: distance
                )
            )
        }

        let ranked = matches.sorted { left, right in
            if left.distance != right.distance {
                return left.distance < right.distance
            }
            if left.observed.count != right.observed.count {
                return left.observed.count > right.observed.count
            }
            return left.replacement < right.replacement
        }
        guard let best = ranked.first else { return nil }
        if let competing = ranked.dropFirst().first,
           competing.distance == best.distance,
           competing.replacement.caseInsensitiveCompare(best.replacement) != .orderedSame {
            return nil
        }
        return best
    }

    private static func suffixWordStarts(
        in text: Substring
    ) -> [Substring.Index] {
        var starts: [Substring.Index] = []
        var isInsideWord = false
        for index in text.indices {
            if text[index].isWhitespace {
                isInsideWord = false
            } else if isInsideWord == false {
                starts.append(index)
                isInsideWord = true
            }
        }
        return starts
    }

    private static func wordCount(in phrase: String) -> Int {
        phrase.split(whereSeparator: \.isWhitespace).count
    }

    private static func maxDistance(for characterCount: Int) -> Int {
        switch characterCount {
        case 0...2: 0
        case 3...7: 1
        default: 2
        }
    }

    private static func normalize(_ value: String) -> String {
        value.lowercased().replacingOccurrences(of: "’", with: "'")
    }

    private static func editDistance(
        _ left: String,
        _ right: String,
        maximumDistance: Int
    ) -> Int {
        let leftCharacters = Array(left)
        let rightCharacters = Array(right)
        guard abs(leftCharacters.count - rightCharacters.count) <= maximumDistance else {
            return maximumDistance + 1
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
            if rowMinimum > maximumDistance {
                return maximumDistance + 1
            }
            previousPrevious = previous
            previous = current
        }
        return previous[rightCharacters.count]
    }

    private static func isPhraseBoundary(_ character: Character) -> Bool {
        character.isLetter == false
            && character.isNumber == false
            && character != "'"
            && character != "’"
    }

}
