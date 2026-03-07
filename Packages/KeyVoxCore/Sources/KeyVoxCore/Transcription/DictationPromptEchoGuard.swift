import Foundation

public enum DictationPromptEchoGuard {
    public nonisolated static func shouldTreatAsNoSpeech(
        processedText: String,
        dictionaryEntries: [DictionaryEntry],
        usedDictionaryHintPrompt: Bool
    ) -> Bool {
        guard usedDictionaryHintPrompt else { return false }

        let normalizedPhrases = dictionaryEntries
            .map { normalizeForMatching($0.phrase) }
            .filter { !$0.isEmpty }
        guard !normalizedPhrases.isEmpty else { return false }

        let chunks = splitChunks(processedText)
        guard chunks.count >= 10 else { return false }

        let dictionaryChunkMatches = chunks.reduce(0) { count, chunk in
            let matchesDictionaryPhrase = normalizedPhrases.contains { phrase in
                chunk == phrase || chunk.contains(phrase)
            }
            return count + (matchesDictionaryPhrase ? 1 : 0)
        }

        let dictionaryChunkRatio = Float(dictionaryChunkMatches) / Float(chunks.count)
        let hasDictionaryChunkFlood = dictionaryChunkRatio >= 0.72

        let modeChunkCount = mostCommonCount(in: chunks)
        let longestRepeatedRun = longestConsecutiveRun(in: chunks)
        let uniqueChunkCount = Set(chunks).count
        let hasLowDiversitySpam = uniqueChunkCount <= max(4, chunks.count / 5)
        let hasRunawayRepetition = longestRepeatedRun >= 6 || modeChunkCount >= max(8, chunks.count / 2)
        let dictionaryWords = Set(normalizedPhrases.flatMap { phrase in
            phrase.split(separator: " ").map(String.init)
        })
        let chunkRuns = consecutiveRuns(in: chunks)
        let hasDictionaryRepeatedRun = chunkRuns.contains { run in
            guard run.count >= 6 else { return false }
            return normalizedPhrases.contains(where: { run.value == $0 || run.value.contains($0) })
                || dictionaryWords.contains(run.value)
        }
        let hasShortNoiseRun = chunkRuns.contains { run in
            run.count >= 8 && run.value.count <= 3
        }

        let words = splitWords(processedText)
        let mostCommonWord = mostCommonElement(in: words)
        let hasDictionaryWordDominance = words.count >= 30
            && dictionaryWords.contains(mostCommonWord.element)
            && Float(mostCommonWord.count) / Float(words.count) >= 0.34

        if hasDictionaryChunkFlood && (hasLowDiversitySpam || hasRunawayRepetition || hasDictionaryWordDominance) {
            return true
        }

        if dictionaryChunkRatio >= 0.35 && hasDictionaryRepeatedRun && hasShortNoiseRun {
            return true
        }

        return false
    }

    nonisolated private static func splitChunks(_ text: String) -> [String] {
        text
            .components(separatedBy: CharacterSet(charactersIn: ",;\n"))
            .map(normalizeForMatching(_:))
            .filter { !$0.isEmpty }
    }

    nonisolated private static func splitWords(_ text: String) -> [String] {
        normalizeForMatching(text)
            .split(separator: " ")
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    nonisolated private static func mostCommonCount(in elements: [String]) -> Int {
        mostCommonElement(in: elements).count
    }

    nonisolated private static func mostCommonElement(in elements: [String]) -> (element: String, count: Int) {
        guard !elements.isEmpty else { return ("", 0) }
        var counts: [String: Int] = [:]
        counts.reserveCapacity(elements.count)
        for element in elements {
            counts[element, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value }).map { ($0.key, $0.value) } ?? ("", 0)
    }

    nonisolated private static func longestConsecutiveRun(in elements: [String]) -> Int {
        guard !elements.isEmpty else { return 0 }
        var longest = 1
        var current = 1
        var previous = elements[0]
        for element in elements.dropFirst() {
            if element == previous {
                current += 1
                if current > longest {
                    longest = current
                }
            } else {
                previous = element
                current = 1
            }
        }
        return longest
    }

    nonisolated private static func consecutiveRuns(in elements: [String]) -> [(value: String, count: Int)] {
        guard !elements.isEmpty else { return [] }
        var runs: [(value: String, count: Int)] = []
        var currentValue = elements[0]
        var currentCount = 1
        for element in elements.dropFirst() {
            if element == currentValue {
                currentCount += 1
            } else {
                runs.append((value: currentValue, count: currentCount))
                currentValue = element
                currentCount = 1
            }
        }
        runs.append((value: currentValue, count: currentCount))
        return runs
    }

    nonisolated private static func normalizeForMatching(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .replacingOccurrences(of: "[^a-z0-9\\.\\s]+", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
