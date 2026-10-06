import Foundation

/// A reproducible typing script shared with the Apple keyboard baseline runner.
///
/// Every tap is stored as an offset from the intended key's center, measured in key
/// pitches (the distance between neighboring key centers horizontally, and between
/// rows vertically). Any keyboard can replay the same fingers on its own key sizes.
struct TypingPlan: Codable {
    struct Sentence: Codable {
        let words: [String]
        /// Per word, per tapped letter: `[dx, dy]` in key pitches.
        let taps: [[[Double]]]
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
