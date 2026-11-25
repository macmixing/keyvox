import CoreGraphics
import KeyVoxPredictiveKeyboard
import Testing
@testable import KeyVox_iOS

/// Swipes for tests: the letter keys of a 390-point-wide iPhone keyboard and a finger's path
/// through a word's letters on them.
enum KeyboardSwipeTestPath {
    static let keyboardSize = CGSize(width: 390, height: 216)

    /// The letter keys of a 390-point-wide iPhone keyboard's three letter rows.
    static let letterKeys: [KeyboardCharacterKeyGeometry] = {
        let rows: [(letters: String, inset: CGFloat)] = [("qwertyuiop", 3), ("asdfghjkl", 22.5), ("zxcvbnm", 61.5)]
        return rows.enumerated().flatMap { row, entry in
            entry.letters.enumerated().map { index, letter in
                KeyboardCharacterKeyGeometry(
                    character: letter,
                    frame: CGRect(x: entry.inset + CGFloat(index) * 39, y: 10 + CGFloat(row) * 54, width: 33, height: 42)
                )
            }
        }
    }()

    /// A finger's path from key center to key center through `word`'s letters, sampled every 16 ms.
    static func through(_ word: String) throws -> [SwipeTouchSample] {
        let centers = try word.map { letter in
            let frame = try #require(letterKeys.first { $0.character == letter }).frame
            return CGPoint(x: frame.midX, y: frame.midY)
        }
        var samples = [SwipeTouchSample(location: centers[0], timestamp: 0)]
        for (from, to) in zip(centers, centers.dropFirst()) {
            for step in 1...8 {
                let fraction = CGFloat(step) / 8
                samples.append(SwipeTouchSample(
                    location: CGPoint(x: from.x + (to.x - from.x) * fraction, y: from.y + (to.y - from.y) * fraction),
                    timestamp: samples[samples.count - 1].timestamp + 0.016
                ))
            }
        }
        return samples
    }
}
