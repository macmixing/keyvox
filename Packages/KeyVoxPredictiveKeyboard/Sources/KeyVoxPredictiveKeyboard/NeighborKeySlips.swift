import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Words the typed letters could have been meant as when two of the taps each landed on a key
/// next to the intended one, as when the hand rests a key off for a word.
///
/// The engine's search reaches words a single slip away, and drops most words two wrong keys
/// away from a short typed word, though a hand a key off types them often. These words are only
/// candidates: the corrector still decides from the touches and the words around them.
struct NeighborKeySlips {
    /// How far outside a key's frame a neighbor's center may lie, in key pitches: the keys beside
    /// it and the keys touching it in the rows above and below, never a key two away.
    private static let neighborDistance = 0.6

    private let neighbors: [Character: [Character]]

    init(keys: KeyCenterMap) {
        var neighbors: [Character: [Character]] = [:]
        for letter in keys.allLetters {
            guard let center = keys.center(of: letter) else { continue }
            neighbors[letter] = keys.letters(near: center, within: Self.neighborDistance)
                .map(\.letter)
                .filter { $0 != letter }
                .sorted()
        }
        self.neighbors = neighbors
    }

    /// The words, among those `isWord` accepts, that differ from `typed` in exactly two letters,
    /// each a neighbor of the key typed in its place. Words of fewer than three letters have none.
    func words(for typed: String, isWord: (String) throws -> Bool) rethrows -> [String] {
        let letters = Array(typed.lowercased())
        guard letters.count >= 3 else { return [] }
        var words: [String] = []
        for first in letters.indices {
            for second in letters.indices where second > first {
                for firstReplacement in neighbors[letters[first]] ?? [] {
                    for secondReplacement in neighbors[letters[second]] ?? [] {
                        var candidate = letters
                        candidate[first] = firstReplacement
                        candidate[second] = secondReplacement
                        let word = String(candidate)
                        if try isWord(word) {
                            words.append(word)
                        }
                    }
                }
            }
        }
        return words
    }
}
