import Foundation

/// The space a field that deletes smartly removes along with a selection the delete key deletes, as
/// measured on iOS with `Tools/AppleKeyboardBaseline` (`SmartDeleteCharacterProbe`). Only a plain
/// space is ever removed: the one before the selection when the end of the text or a character the
/// field lists for after a word follows the selection, or else the one after it when the start of
/// the text or a character the field lists for before a word comes before the selection.
enum KeyboardSmartDeletion {
    enum RemovedSpace: Equatable {
        case before
        case after
    }

    private static let space: Unicode.Scalar = " "
    private static let charactersBeforeWord = bundledCharacters("smart_delete_before_word_characters")
    private static let charactersAfterWord = bundledCharacters("smart_delete_after_word_characters")

    /// - Parameters:
    ///   - textBefore: The text before the deleted selection.
    ///   - textAfter: The text after it.
    static func removedSpace(textBefore: String, textAfter: String) -> RemovedSpace? {
        let before = textBefore.unicodeScalars.last
        let after = textAfter.unicodeScalars.first
        if before == space, after.map(charactersAfterWord.contains) ?? true {
            return .before
        }
        if after == space, before.map(charactersBeforeWord.contains) ?? true {
            return .after
        }
        return nil
    }

    /// A bundled list of characters, one hexadecimal scalar or range of them per line, as "0021" or
    /// "3400-4DBF".
    private static func bundledCharacters(_ name: String) -> CharacterSet {
        guard let url = Bundle.main.url(forResource: name, withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("missing \(name).txt")
            return CharacterSet()
        }
        var characters = CharacterSet()
        for line in text.split(separator: "\n") {
            let bounds = line.split(separator: "-").compactMap { UInt32($0, radix: 16).flatMap(Unicode.Scalar.init) }
            guard let first = bounds.first, let last = bounds.last else { continue }
            characters.insert(charactersIn: first...last)
        }
        return characters
    }
}
