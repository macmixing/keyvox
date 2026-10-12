import Foundation

/// The characters a key offers when the user presses and holds it, as the system keyboard
/// offers them: accented letters on letter keys and related marks on symbol keys.
///
/// The bundled list has a line per key: the character the key types, a tab, the side its popup
/// opens toward (`right`, `left`, or `strictly-left`, which never spills to the right), a tab,
/// and the popup's characters separated by spaces. The first is what lifting the finger without
/// sliding types: usually the key's own character, but the apostrophe key, which types a curly
/// apostrophe, offers a straight one first.
public struct HeldKeyCharacters: Sendable {
    /// The side of the key a popup's characters run toward.
    public enum Direction: String, Sendable {
        case right
        case left
        /// Left, never spilling to the right however little room there is.
        case strictlyLeft = "strictly-left"
    }

    /// What holding one key offers.
    public struct Offer: Sendable, Equatable {
        /// The popup's characters, the first being what the key types when the finger stays put,
        /// then the rest in order outward from it.
        public let characters: [String]
        public let direction: Direction
    }

    private let offers: [String: Offer]

    public init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        var offers: [String: Offer] = [:]
        for line in text.split(separator: "\n") {
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            let characters = fields.count == 3 ? fields[2].split(separator: " ").map(String.init) : []
            guard characters.count > 1, let direction = Direction(rawValue: String(fields[1])) else {
                throw PredictiveKeyboardError.invalidHeldKeyCharacters
            }
            offers[String(fields[0])] = Offer(characters: characters, direction: direction)
        }
        self.offers = offers
    }

    /// The list bundled with the keyboard.
    public static func bundled() throws -> HeldKeyCharacters {
        try HeldKeyCharacters(contentsOf: PredictiveArtifactLocator().url(name: "held_key_characters", extension: "txt"))
    }

    /// What holding the key that types `key` offers, or nil for a key holding does nothing on.
    public func offer(forKey key: String) -> Offer? {
        offers[key]
    }
}
