#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

/// Where each letter of the word being typed was tapped, kept in step with the text.
///
/// Touches are only trusted while they line up one-to-one with the letters before the
/// cursor; any edit that breaks that (pasting, moving the cursor, a long-press accent)
/// drops them and the word is scored from key centers instead.
public struct TypedWordTouches: Sendable, Equatable {
    public private(set) var word = ""
    public private(set) var touches: [CGPoint] = []
    /// The rest of the word right after the cursor, lowercased, as last synchronized.
    private var restOfWord = ""

    public init() {}

    /// Call after a tapped letter has been inserted.
    public mutating func recordTap(at location: CGPoint, currentWord: String) {
        let normalized = currentWord.lowercased()
        if normalized.count == word.count + 1, normalized.hasPrefix(word) {
            word = normalized
            touches.append(location)
        } else if normalized.count == 1 {
            word = normalized
            touches = [location]
        } else {
            reset()
        }
    }

    /// Call after any other change to the text around the cursor. `restOfWord` is the rest of the
    /// word right after the cursor: a deletion leaves it as it was, while a cursor move puts the
    /// letters it passed over in front of it, which drops the touches.
    public mutating func synchronize(currentWord: String, restOfWord: String = "") {
        let normalized = currentWord.lowercased()
        let rest = restOfWord.lowercased()
        defer { self.restOfWord = rest }
        guard normalized != word else { return }
        if normalized.isEmpty == false, word.hasPrefix(normalized),
           rest != word.dropFirst(normalized.count) + self.restOfWord {
            touches = Array(touches.prefix(normalized.count))
            word = normalized
        } else {
            reset()
        }
    }

    /// Touches for `currentWord` if they still line up with it, otherwise none.
    public func touches(for currentWord: String) -> [CGPoint] {
        currentWord.lowercased() == word ? touches : []
    }

    public mutating func reset() {
        word = ""
        touches = []
        restOfWord = ""
    }
}
