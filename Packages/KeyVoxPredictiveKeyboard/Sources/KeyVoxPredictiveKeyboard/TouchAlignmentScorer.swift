import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// How unlikely it is, in nats, that a sequence of touches was an attempt to type a word.
///
/// Each touch is aligned to a letter of the word. An aligned touch costs its squared
/// distance from that letter's key center under a Gaussian finger model; touches with no
/// letter (extra taps), letters with no touch (skipped letters), and swapped neighboring
/// letters each add a fixed cost. Apostrophes are never tapped and cost nothing to skip.
public struct TouchAlignmentScorer: Sendable {
    public struct Parameters: Sendable, Equatable {
        /// Finger spread around the intended key center, in key pitches.
        public var touchStandardDeviation: Double
        public var extraTouchCost: Double
        public var skippedLetterCost: Double
        /// Skipping one letter of a doubled pair ("leter" for "letter").
        public var skippedRepeatedLetterCost: Double
        public var swappedLettersCost: Double

        public init(
            touchStandardDeviation: Double,
            extraTouchCost: Double,
            skippedLetterCost: Double,
            skippedRepeatedLetterCost: Double,
            swappedLettersCost: Double
        ) {
            self.touchStandardDeviation = touchStandardDeviation
            self.extraTouchCost = extraTouchCost
            self.skippedLetterCost = skippedLetterCost
            self.skippedRepeatedLetterCost = skippedRepeatedLetterCost
            self.swappedLettersCost = swappedLettersCost
        }
    }

    public let keys: KeyCenterMap
    public let parameters: Parameters

    public init(keys: KeyCenterMap, parameters: Parameters) {
        self.keys = keys
        self.parameters = parameters
    }

    public func cost(of touches: [CGPoint], typing word: String) -> Double {
        let letters = Array(Self.foldedLetters(word))
        let touchCount = touches.count
        let letterCount = letters.count
        let unreachable = Double.greatestFiniteMagnitude / 4
        var table = Array(
            repeating: Array(repeating: unreachable, count: letterCount + 1),
            count: touchCount + 1
        )
        table[0][0] = 0

        for touchIndex in 0...touchCount {
            for letterIndex in 0...letterCount {
                var best = table[touchIndex][letterIndex]
                if touchIndex > 0, letterIndex > 0 {
                    best = min(
                        best,
                        table[touchIndex - 1][letterIndex - 1]
                            + aimCost(touches[touchIndex - 1], letters[letterIndex - 1])
                    )
                }
                if touchIndex > 0 {
                    best = min(best, table[touchIndex - 1][letterIndex] + parameters.extraTouchCost)
                }
                if letterIndex > 0 {
                    best = min(
                        best,
                        table[touchIndex][letterIndex - 1] + skipCost(letters, at: letterIndex - 1)
                    )
                }
                if touchIndex > 1, letterIndex > 1,
                   letters[letterIndex - 1] != letters[letterIndex - 2] {
                    best = min(
                        best,
                        table[touchIndex - 2][letterIndex - 2]
                            + aimCost(touches[touchIndex - 2], letters[letterIndex - 1])
                            + aimCost(touches[touchIndex - 1], letters[letterIndex - 2])
                            + parameters.swappedLettersCost
                    )
                }
                table[touchIndex][letterIndex] = best
            }
        }
        return table[touchCount][letterCount]
    }

    /// Touches at the centers of the typed letters' keys, for input that arrived without
    /// touch positions.
    public func centerTouches(for typedWord: String) -> [CGPoint] {
        Self.foldedLetters(typedWord).compactMap { keys.center(of: $0) }
    }

    private func aimCost(_ touch: CGPoint, _ letter: Character) -> Double {
        guard letter != "'" else { return parameters.extraTouchCost }
        guard let center = keys.center(of: letter) else { return parameters.extraTouchCost }
        let dx = Double(touch.x - center.x) / Double(keys.pitch.width)
        let dy = Double(touch.y - center.y) / Double(keys.pitch.height)
        let variance = parameters.touchStandardDeviation * parameters.touchStandardDeviation
        return (dx * dx + dy * dy) / (2 * variance)
    }

    private func skipCost(_ letters: [Character], at index: Int) -> Double {
        if letters[index] == "'" { return 0 }
        if index > 0, letters[index - 1] == letters[index] {
            return parameters.skippedRepeatedLetterCost
        }
        return parameters.skippedLetterCost
    }

    /// Lowercased letters with accents removed, so "café" is aimed at the plain "e" key.
    private static func foldedLetters(_ word: String) -> String {
        word.replacingOccurrences(of: "’", with: "'")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
