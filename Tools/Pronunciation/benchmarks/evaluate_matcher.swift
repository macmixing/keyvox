#!/usr/bin/swift
import Foundation

struct ReplacementScore {
    let text: Double
    let phonetic: Double
    let context: Double
    let final: Double
}

struct ReplacementScorer {
    static let balanced = ReplacementScorer(
        textWeight: 0.50,
        phoneticWeight: 0.40,
        contextWeight: 0.10,
        ambiguityMargin: 0.05,
        commonWordOverrideThreshold: 0.94
    )

    let textWeight: Double
    let phoneticWeight: Double
    let contextWeight: Double
    let ambiguityMargin: Double
    let commonWordOverrideThreshold: Double

    func threshold(for tokenCount: Int) -> Double {
        switch tokenCount {
        case 1:
            return 0.90
        case 2:
            return 0.80
        default:
            return 0.78
        }
    }

    func score(
        observedText: String,
        observedPhonetic: String,
        candidateText: String,
        candidatePhonetic: String,
        previousToken: String?,
        nextToken: String?
    ) -> ReplacementScore {
        let textScore = similarity(lhs: observedText, rhs: candidateText)
        let phoneticScore = similarity(lhs: observedPhonetic, rhs: candidatePhonetic)
        let contextScore = contextScore(previousToken: previousToken, nextToken: nextToken)

        let finalScore = (textWeight * textScore)
            + (phoneticWeight * phoneticScore)
            + (contextWeight * contextScore)

        return ReplacementScore(
            text: textScore,
            phonetic: phoneticScore,
            context: contextScore,
            final: finalScore
        )
    }

    func similarity(lhs: String, rhs: String) -> Double {
        guard !lhs.isEmpty && !rhs.isEmpty else { return 0 }
        if lhs == rhs { return 1 }

        let lhsChars = Array(lhs)
        let rhsChars = Array(rhs)
        if lhsChars.isEmpty { return rhsChars.isEmpty ? 1 : 0 }
        if rhsChars.isEmpty { return 0 }

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

        let distance = previous[rhsChars.count]
        let maxLength = max(lhsChars.count, rhsChars.count)
        return max(0, 1 - (Double(distance) / Double(maxLength)))
    }

    private func contextScore(previousToken: String?, nextToken: String?) -> Double {
        var score = 0.45
        if let previousToken, !previousToken.isEmpty { score += 0.25 }
        if let nextToken, !nextToken.isEmpty { score += 0.25 }
        return min(score, 1.0)
    }
}

enum TextNormalization {
    static func normalizedPhrase(_ input: String) -> String {
        let folded = input.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let lower = folded.lowercased()
        let spaced = lower.replacingOccurrences(of: "[^a-z0-9']+", with: " ", options: .regularExpression)
        return spaced
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }

    static func normalizedToken(_ input: String) -> String {
        normalizedPhrase(input).replacingOccurrences(of: " ", with: "")
    }

    static func tokenized(_ input: String) -> [String] {
        let phrase = normalizedPhrase(input)
        guard !phrase.isEmpty else { return [] }
        return phrase.split(separator: " ").map(String.init)
    }
}

struct PhoneticEncoder {
    let lexicon: [String: String]

    func signature(for token: String) -> String {
        if let known = lexicon[token] {
            return known
        }
        return fallbackSignature(for: token)
    }

    private func fallbackSignature(for token: String) -> String {
        guard !token.isEmpty else { return "" }
        var output = ""
        var lastCode: Character?
        for char in token.lowercased() {
            guard let code = phoneticCode(for: char) else { continue }
            if output.isEmpty {
                output.append(code)
                lastCode = code
                continue
            }
            if code == "A" || code == lastCode { continue }
            output.append(code)
            lastCode = code
            if output.count >= 8 { break }
        }
        return output.isEmpty ? token : output
    }

    private func phoneticCode(for character: Character) -> Character? {
        switch character {
        case "a", "e", "i", "o", "u", "y":
            return "A"
        case "b", "p":
            return "B"
        case "c", "k", "q", "g":
            return "K"
        case "d", "t":
            return "T"
        case "f", "v":
            return "F"
        case "j":
            return "J"
        case "l":
            return "L"
        case "m", "n":
            return "N"
        case "r":
            return "R"
        case "s", "z", "x":
            return "S"
        case "h", "w":
            return nil
        case "0"..."9":
            return character
        default:
            return nil
        }
    }
}

struct CompiledEntry {
    let phrase: String
    let normalizedPhrase: String
    let tokens: [String]
    let phoneticPhrase: String
}

struct ProposedReplacement {
    let tokenStart: Int
    let tokenEndExclusive: Int
    let replacementTokens: [String]
    let score: Double
}

final class OfflineMatcher {
    private let encoder: PhoneticEncoder
    private let scorer = ReplacementScorer.balanced
    private let commonWords: Set<String>
    private var entriesByTokenCount: [Int: [CompiledEntry]] = [:]
    private var entriesByTokenCountAndPrefix: [Int: [Character: [CompiledEntry]]] = [:]

    init(lexicon: [String: String], commonWords: Set<String>) {
        self.encoder = PhoneticEncoder(lexicon: lexicon)
        self.commonWords = commonWords
    }

    func rebuild(entries: [String]) {
        var grouped: [Int: [CompiledEntry]] = [:]
        var groupedByPrefix: [Int: [Character: [CompiledEntry]]] = [:]
        for phrase in entries {
            let normalizedPhrase = TextNormalization.normalizedPhrase(phrase)
            guard !normalizedPhrase.isEmpty else { continue }
            let tokens = normalizedPhrase.split(separator: " ").map(String.init)
            guard !tokens.isEmpty, tokens.count <= 4 else { continue }
            let phoneticPhrase = tokens.map { encoder.signature(for: $0) }.joined(separator: " ")
            let compiled = CompiledEntry(
                phrase: phrase,
                normalizedPhrase: normalizedPhrase,
                tokens: tokens,
                phoneticPhrase: phoneticPhrase
            )
            grouped[tokens.count, default: []].append(compiled)
            if let first = tokens.first?.first {
                groupedByPrefix[tokens.count, default: [:]][first, default: []].append(compiled)
            }
        }
        entriesByTokenCount = grouped
        entriesByTokenCountAndPrefix = groupedByPrefix
    }

    func apply(to input: String) -> String {
        let tokens = TextNormalization.tokenized(input)
        guard !tokens.isEmpty, !entriesByTokenCount.isEmpty else {
            return TextNormalization.normalizedPhrase(input)
        }

        let phonetics = tokens.map { encoder.signature(for: $0) }
        var proposed: [ProposedReplacement] = []

        for start in tokens.indices {
            for tokenCount in 1...4 {
                let end = start + tokenCount
                guard end <= tokens.count else { continue }
                guard let allCandidates = entriesByTokenCount[tokenCount], !allCandidates.isEmpty else { continue }
                let candidates: [CompiledEntry]
                if let prefix = tokens[start].first,
                   let narrowed = entriesByTokenCountAndPrefix[tokenCount]?[prefix],
                   !narrowed.isEmpty {
                    candidates = narrowed
                } else {
                    candidates = allCandidates
                }

                let observedTokens = Array(tokens[start..<end])
                let observedNormalized = observedTokens.joined(separator: " ")
                let observedPhonetic = Array(phonetics[start..<end]).joined(separator: " ")

                var best: (CompiledEntry, ReplacementScore)?
                var secondBestScore = 0.0

                for candidate in candidates {
                    let base = scorer.score(
                        observedText: observedNormalized,
                        observedPhonetic: observedPhonetic,
                        candidateText: candidate.normalizedPhrase,
                        candidatePhonetic: candidate.phoneticPhrase,
                        previousToken: start > 0 ? tokens[start - 1] : nil,
                        nextToken: end < tokens.count ? tokens[end] : nil
                    )

                    let boosted = min(
                        1.0,
                        base.final + tokenAlignmentBoost(
                            observed: observedTokens,
                            observedPhonetics: Array(phonetics[start..<end]),
                            candidate: candidate
                        )
                    )

                    let score = ReplacementScore(
                        text: base.text,
                        phonetic: base.phonetic,
                        context: base.context,
                        final: boosted
                    )

                    if let currentBest = best {
                        if score.final > currentBest.1.final {
                            secondBestScore = currentBest.1.final
                            best = (candidate, score)
                        } else if score.final > secondBestScore {
                            secondBestScore = score.final
                        }
                    } else {
                        best = (candidate, score)
                    }
                }

                guard let winner = best else { continue }
                let observedPhrase = observedTokens.joined(separator: " ")
                let exact = observedPhrase == winner.0.normalizedPhrase

                if tokenCount == 1 && observedTokens[0].count < 3 && !exact {
                    continue
                }

                if winner.1.final < scorer.threshold(for: tokenCount) {
                    continue
                }

                if secondBestScore > 0 && (winner.1.final - secondBestScore) < scorer.ambiguityMargin {
                    continue
                }

                if tokenCount == 1,
                   commonWords.contains(observedTokens[0]),
                   winner.1.final < scorer.commonWordOverrideThreshold {
                    continue
                }

                if observedPhrase == winner.0.normalizedPhrase {
                    continue
                }

                proposed.append(
                    ProposedReplacement(
                        tokenStart: start,
                        tokenEndExclusive: end,
                        replacementTokens: winner.0.tokens,
                        score: winner.1.final
                    )
                )
            }
        }

        let selected = selectNonOverlapping(from: proposed)
        guard !selected.isEmpty else {
            return tokens.joined(separator: " ")
        }

        let byStart = Dictionary(uniqueKeysWithValues: selected.map { ($0.tokenStart, $0) })
        var output: [String] = []
        var index = 0
        while index < tokens.count {
            if let replacement = byStart[index] {
                output.append(contentsOf: replacement.replacementTokens)
                index = replacement.tokenEndExclusive
            } else {
                output.append(tokens[index])
                index += 1
            }
        }

        return output.joined(separator: " ")
    }

    private func selectNonOverlapping(from proposed: [ProposedReplacement]) -> [ProposedReplacement] {
        let sorted = proposed.sorted {
            if $0.score == $1.score {
                let lhsLen = $0.tokenEndExclusive - $0.tokenStart
                let rhsLen = $1.tokenEndExclusive - $1.tokenStart
                if lhsLen == rhsLen {
                    return $0.tokenStart < $1.tokenStart
                }
                return lhsLen > rhsLen
            }
            return $0.score > $1.score
        }

        var selected: [ProposedReplacement] = []
        for candidate in sorted {
            let overlaps = selected.contains { existing in
                candidate.tokenStart < existing.tokenEndExclusive && existing.tokenStart < candidate.tokenEndExclusive
            }
            if !overlaps {
                selected.append(candidate)
            }
        }
        return selected
    }

    private func tokenAlignmentBoost(observed: [String], observedPhonetics: [String], candidate: CompiledEntry) -> Double {
        guard observed.count == candidate.tokens.count, !observed.isEmpty else { return 0 }

        let candidatePhonetics = candidate.tokens.map { encoder.signature(for: $0) }
        var exactMatches = 0
        var strongMatches = 0
        var firstTokenExact = false

        for index in observed.indices {
            let observedToken = observed[index]
            let candidateToken = candidate.tokens[index]
            let textScore = scorer.similarity(lhs: observedToken, rhs: candidateToken)
            let phoneticScore = scorer.similarity(lhs: observedPhonetics[index], rhs: candidatePhonetics[index])
            let blended = (0.55 * textScore) + (0.45 * phoneticScore)

            if textScore == 1.0 {
                exactMatches += 1
                if index == 0 {
                    firstTokenExact = true
                }
            }

            if textScore >= 0.78 || phoneticScore >= 0.78 || blended >= 0.78 {
                strongMatches += 1
            }
        }

        if observed.count == 2, firstTokenExact {
            let textTail = scorer.similarity(lhs: observed[1], rhs: candidate.tokens[1])
            let phoneticTail = scorer.similarity(lhs: observedPhonetics[1], rhs: candidatePhonetics[1])
            if textTail >= 0.70 || phoneticTail >= 0.72 {
                return 0.12
            }
        }

        if firstTokenExact && strongMatches == observed.count { return 0.08 }
        if exactMatches >= 1 && strongMatches == observed.count { return 0.06 }
        if strongMatches == observed.count { return 0.04 }
        return 0
    }
}

struct PositiveCase {
    let observed: String
    let expected: String
}

struct QualityMetrics {
    let coverage: Double
    let hitRate: Double
    let falsePositiveRate: Double
    let medianLatencyMS: Double
}

func loadLines(at path: String) throws -> [String] {
    let content = try String(contentsOfFile: path, encoding: .utf8)
    return content
        .split(whereSeparator: \.isNewline)
        .map(String.init)
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty && !$0.hasPrefix("#") }
}

func loadLexicon(at path: String) throws -> [String: String] {
    var map: [String: String] = [:]
    for line in try loadLines(at: path) {
        let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { continue }
        let word = TextNormalization.normalizedToken(String(parts[0]))
        let signature = String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !word.isEmpty, !signature.isEmpty else { continue }
        map[word] = signature
    }
    return map
}

func loadPositiveCases(at path: String) throws -> [PositiveCase] {
    var cases: [PositiveCase] = []
    for line in try loadLines(at: path) {
        let parts = line.split(separator: "\t", maxSplits: 1, omittingEmptySubsequences: false)
        guard parts.count == 2 else { continue }
        cases.append(PositiveCase(observed: String(parts[0]), expected: String(parts[1])))
    }
    return cases
}

func parseRepoRoot() -> String {
    let args = CommandLine.arguments
    if let index = args.firstIndex(of: "--repo-root"), index + 1 < args.count {
        return args[index + 1]
    }
    return FileManager.default.currentDirectoryPath
}

func median(_ values: [Double]) -> Double {
    guard !values.isEmpty else { return 0 }
    let sorted = values.sorted()
    let mid = sorted.count / 2
    if sorted.count % 2 == 0 {
        return (sorted[mid - 1] + sorted[mid]) / 2
    }
    return sorted[mid]
}

func evaluate(repoRoot: String) throws -> QualityMetrics {
    let pronunciationDir = "\(repoRoot)/Resources/Pronunciation"
    let benchmarkDir = "\(repoRoot)/Tools/Pronunciation/benchmarks"

    let lexicon = try loadLexicon(at: "\(pronunciationDir)/lexicon-v1.tsv")
    let commonWords = Set(try loadLines(at: "\(pronunciationDir)/common-words-v1.txt").map(TextNormalization.normalizedToken))
    let dictionaryEntries = try loadLines(at: "\(benchmarkDir)/dictionary-entries.txt")
    let positiveCases = try loadPositiveCases(at: "\(benchmarkDir)/positive-cases.tsv")
    let safetyCases = try loadLines(at: "\(benchmarkDir)/safety-cases.txt")
    let coverageCorpus = try loadLines(at: "\(benchmarkDir)/coverage-corpus.txt")

    let matcher = OfflineMatcher(lexicon: lexicon, commonWords: commonWords)
    matcher.rebuild(entries: dictionaryEntries)

    var hits = 0
    let debugCases = ProcessInfo.processInfo.environment["KEYVOX_DEBUG_CASES"] == "1"
    for testCase in positiveCases {
        let actual = TextNormalization.normalizedPhrase(matcher.apply(to: testCase.observed))
        let expected = TextNormalization.normalizedPhrase(testCase.expected)
        if debugCases {
            print("CASE observed='\(TextNormalization.normalizedPhrase(testCase.observed))' actual='\(actual)' expected='\(expected)'")
        }
        if actual == expected {
            hits += 1
        }
    }
    let hitRate = positiveCases.isEmpty ? 100.0 : (Double(hits) / Double(positiveCases.count) * 100.0)

    var falsePositives = 0
    for sample in safetyCases {
        let before = TextNormalization.normalizedPhrase(sample)
        let after = TextNormalization.normalizedPhrase(matcher.apply(to: sample))
        if before != after {
            falsePositives += 1
        }
    }
    let falsePositiveRate = safetyCases.isEmpty ? 0.0 : (Double(falsePositives) / Double(safetyCases.count) * 100.0)

    var coverageTotal = 0
    var coverageHit = 0
    for sample in coverageCorpus {
        for token in TextNormalization.tokenized(sample) {
            coverageTotal += 1
            if lexicon[token] != nil {
                coverageHit += 1
            }
        }
    }
    let coverage = coverageTotal == 0 ? 100.0 : (Double(coverageHit) / Double(coverageTotal) * 100.0)

    var latencyEntries = dictionaryEntries
    if latencyEntries.count < 500 {
        let sortedWords = lexicon.keys.sorted()
        let needed = 500 - latencyEntries.count
        let stride = max(1, sortedWords.count / max(needed, 1))
        var index = 0
        while index < sortedWords.count, latencyEntries.count < 500 {
            latencyEntries.append(sortedWords[index])
            index += stride
        }
        if latencyEntries.count < 500 {
            for word in sortedWords {
                if latencyEntries.count >= 500 { break }
                latencyEntries.append(word)
            }
        }
    } else if latencyEntries.count > 500 {
        latencyEntries = Array(latencyEntries.prefix(500))
    }

    matcher.rebuild(entries: latencyEntries)
    let transcriptTokens = coverageCorpus
        .flatMap { TextNormalization.tokenized($0) }
    let transcript = Array(transcriptTokens.prefix(40)).joined(separator: " ")
    let benchmarkText = transcript.isEmpty ? "dom espicito qboard keybox" : transcript

    var samples: [Double] = []
    samples.reserveCapacity(250)
    for _ in 0..<250 {
        let start = DispatchTime.now().uptimeNanoseconds
        _ = matcher.apply(to: benchmarkText)
        let end = DispatchTime.now().uptimeNanoseconds
        samples.append(Double(end - start) / 1_000_000.0)
    }
    let medianLatencyMS = median(samples)

    return QualityMetrics(
        coverage: coverage,
        hitRate: hitRate,
        falsePositiveRate: falsePositiveRate,
        medianLatencyMS: medianLatencyMS
    )
}

do {
    let metrics = try evaluate(repoRoot: parseRepoRoot())
    print(String(format: "COVERAGE=%.2f", metrics.coverage))
    print(String(format: "HIT_RATE=%.2f", metrics.hitRate))
    print(String(format: "FALSE_POSITIVE_RATE=%.2f", metrics.falsePositiveRate))
    print(String(format: "MEDIAN_LATENCY_MS=%.2f", metrics.medianLatencyMS))
} catch {
    fputs("Benchmark evaluation failed: \(error)\n", stderr)
    exit(1)
}
