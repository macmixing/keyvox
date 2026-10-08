import Foundation

/// Whether one word could have been typed for another with a single slip: one wrong key,
/// one missed or extra letter, or two neighboring letters swapped. Case and apostrophes are
/// ignored, so restoring an apostrophe ("its" for "it's") is no slip at all.
enum TypingSlip {
    static func isAtMostOne(between typed: String, and word: String) -> Bool {
        let left = letters(of: typed)
        let right = letters(of: word)
        if left == right { return true }
        if left.count == right.count {
            let differences = left.indices.filter { left[$0] != right[$0] }
            if differences.count == 1 { return true }
            return differences.count == 2
                && differences[1] == differences[0] + 1
                && left[differences[0]] == right[differences[1]]
                && left[differences[1]] == right[differences[0]]
        }
        guard abs(left.count - right.count) == 1 else { return false }
        let (shorter, longer) = left.count < right.count ? (left, right) : (right, left)
        var shorterIndex = 0
        var longerIndex = 0
        var hasSkipped = false
        while shorterIndex < shorter.count, longerIndex < longer.count {
            if shorter[shorterIndex] == longer[longerIndex] {
                shorterIndex += 1
            } else if hasSkipped {
                return false
            } else {
                hasSkipped = true
            }
            longerIndex += 1
        }
        return true
    }

    private static func letters(of word: String) -> [Character] {
        Array(word.lowercased().filter { $0 != "'" && $0 != "’" })
    }
}
