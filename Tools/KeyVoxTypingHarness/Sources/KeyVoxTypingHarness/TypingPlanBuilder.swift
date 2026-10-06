import Foundation

/// Builds a typing plan: picks sentences from the corpus and draws a Gaussian finger
/// offset for every letter that will be tapped.
enum TypingPlanBuilder {
    static func build(
        corpusPaths: [String],
        sentenceLimit: Int,
        noiseInKeyPitches: Double,
        seed: UInt64
    ) throws -> TypingPlan {
        var shuffleGenerator = SeededRandomGenerator(seed: seed ^ 0x5EED)
        let sentences = try CorpusLoader.sentences(from: corpusPaths)
            .compactMap(SentenceWords.init(sentence:))
            .shuffled(using: &shuffleGenerator)
            .prefix(sentenceLimit)

        var tapGenerator = SeededRandomGenerator(seed: seed)
        let planned = sentences.map { sentence in
            TypingPlan.Sentence(
                words: sentence.words,
                taps: sentence.words.map { word in
                    word.filter { $0 != "'" }.map { _ in
                        gaussianPair(standardDeviation: noiseInKeyPitches, generator: &tapGenerator)
                    }
                }
            )
        }
        return TypingPlan(noiseInKeyPitches: noiseInKeyPitches, seed: seed, sentences: planned)
    }

    private static func gaussianPair(
        standardDeviation: Double,
        generator: inout SeededRandomGenerator
    ) -> [Double] {
        guard standardDeviation > 0 else { return [0, 0] }
        let first = Double.random(in: Double.leastNonzeroMagnitude..<1, using: &generator)
        let second = Double.random(in: 0..<1, using: &generator)
        let radius = (-2 * log(first)).squareRoot() * standardDeviation
        let angle = 2 * Double.pi * second
        return [radius * cos(angle), radius * sin(angle)]
    }
}
