import Foundation

/// A reproducible typing script shared with the Apple keyboard baseline runner.
///
/// Every tap is stored as an offset from the intended key's center, measured in key
/// pitches (the distance between neighboring key centers horizontally, and between
/// rows vertically). Any keyboard can replay the same fingers on its own key sizes.
struct TypingPlan: Codable {
    struct Sentence: Codable {
        /// The letters to tap, word by word.
        let words: [String]
        /// Per word, per tapped letter: `[dx, dy]` in key pitches.
        let taps: [[[Double]]]
        /// What the typist meant, when the tapped letters are a recorded human attempt
        /// rather than the intended words themselves.
        var intended: [String]? = nil

        /// The words a correct result must contain.
        var truthWords: [String] { intended ?? words }
    }

    let noiseInKeyPitches: Double
    let seed: UInt64
    let sentences: [Sentence]

    static func load(from path: String) throws -> TypingPlan {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(TypingPlan.self, from: data)
    }

    func write(to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(self).write(to: URL(fileURLWithPath: path))
    }
}
