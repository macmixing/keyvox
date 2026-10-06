import Foundation

/// The typing plan written by `KeyVoxTypingHarness plan`. Each tap is an offset from
/// the intended key's center in key pitches.
struct BaselinePlan: Decodable {
    struct Sentence: Decodable {
        let words: [String]
        let taps: [[[Double]]]
    }

    let noiseInKeyPitches: Double
    let seed: UInt64
    let sentences: [Sentence]

    static func load(from path: String) throws -> BaselinePlan {
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        return try JSONDecoder().decode(BaselinePlan.self, from: data)
    }
}
