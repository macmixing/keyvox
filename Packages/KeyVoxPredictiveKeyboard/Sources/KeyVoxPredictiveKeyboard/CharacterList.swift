import Foundation

/// A bundled list of characters that typing treats alike, as the system keyboard does, one per
/// line.
public struct CharacterList: Sendable {
    private let characters: Set<String>

    public init(contentsOf url: URL) throws {
        let text = try String(contentsOf: url, encoding: .utf8)
        characters = Set(text.split(separator: "\n").map(String.init))
        guard characters.isEmpty == false else {
            throw PredictiveKeyboardError.invalidCharacterList
        }
    }

    /// The characters that end the word before them, so typing one right after a word
    /// autocorrects it as space does; the rest, such as digits, an opening bracket, or an
    /// apostrophe, carry the word on.
    public static func wordEnding() throws -> CharacterList {
        try bundled("word_ending_characters")
    }

    /// The characters that take the place of the space a word picked from the suggestion bar
    /// added, such as a period, a closing bracket, or an apostrophe; the rest follow the space.
    public static func takingPickedWordSpace() throws -> CharacterList {
        try bundled("picked_word_space_characters")
    }

    /// The characters a word picked from the suggestion bar is spaced away from, such as a comma
    /// or a closing bracket: tapping a suggestion right after one first adds the space, and the
    /// next tap picks; the rest take the picked word right after them.
    public static func spacedFromPickedWord() throws -> CharacterList {
        try bundled("spaced_from_picked_word_characters")
    }

    /// The characters the suggestion bar offers no next words right after, such as a hyphen, a
    /// slash, or a currency sign.
    public static func withoutNextWords() throws -> CharacterList {
        try bundled("no_next_word_characters")
    }

    public func contains(_ character: String) -> Bool {
        characters.contains(character)
    }

    private static func bundled(_ name: String) throws -> CharacterList {
        try CharacterList(contentsOf: PredictiveArtifactLocator().url(name: name, extension: "txt"))
    }
}
