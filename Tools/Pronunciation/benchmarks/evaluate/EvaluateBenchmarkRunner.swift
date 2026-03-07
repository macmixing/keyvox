import Foundation

func evaluate(repoRoot: String, debugCases: Bool) throws -> QualityMetrics {
    let pronunciationDir = "\(repoRoot)/Packages/KeyVoxCore/Sources/KeyVoxCore/Resources/Pronunciation"
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
    let transcriptTokens = coverageCorpus.flatMap { TextNormalization.tokenized($0) }
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

func runEvaluateMatcherMain(arguments: [String], environment: [String: String]) -> Int32 {
    do {
        let metrics = try evaluate(
            repoRoot: parseRepoRoot(from: arguments),
            debugCases: environment["KEYVOX_DEBUG_CASES"] == "1"
        )
        print(String(format: "COVERAGE=%.2f", metrics.coverage))
        print(String(format: "HIT_RATE=%.2f", metrics.hitRate))
        print(String(format: "FALSE_POSITIVE_RATE=%.2f", metrics.falsePositiveRate))
        print(String(format: "MEDIAN_LATENCY_MS=%.2f", metrics.medianLatencyMS))
        return 0
    } catch {
        fputs("Benchmark evaluation failed: \(error)\n", stderr)
        return 1
    }
}
