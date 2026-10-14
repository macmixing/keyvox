import Foundation

/// The emoji the system emoji keyboard shows, in its categories and order, with each emoji's
/// Unicode name and skin-tone variants, written by `Tools/KeyVoxEmojiData/write_emoji_catalog.py`.
/// A host shows only those its system can draw.
public struct EmojiCatalog: Sendable {
    public let sections: [EmojiKeyboardSection]

    public static func bundled() throws -> EmojiCatalog {
        try EmojiCatalog(contentsOf: EmojiDataLocator().url(name: "emoji_catalog", extension: "txt"))
    }

    /// Reads a catalog of category lines ("@" and an `EmojiKeyboardCategory` identifier), each
    /// followed by its emoji lines: the emoji, its name, and its skin-tone variants separated by
    /// spaces, split by tabs.
    public init(contentsOf url: URL) throws {
        var sections: [EmojiKeyboardSection] = []
        var category: EmojiKeyboardCategory?
        var emoji: [Emoji] = []
        let lines = try String(contentsOf: url, encoding: .utf8).split(separator: "\n", omittingEmptySubsequences: false)
        for (index, line) in lines.enumerated() where line.isEmpty == false {
            if line.hasPrefix("@") {
                if let category {
                    sections.append(EmojiKeyboardSection(category: category, emoji: emoji))
                }
                guard let next = EmojiKeyboardCategory(rawValue: String(line.dropFirst())),
                      next != .frequentlyUsed else {
                    throw EmojiDataError.invalidCatalog(line: index + 1)
                }
                category = next
                emoji = []
                continue
            }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard category != nil, fields.count == 3, fields[0].isEmpty == false else {
                throw EmojiDataError.invalidCatalog(line: index + 1)
            }
            emoji.append(Emoji(
                text: String(fields[0]),
                name: String(fields[1]),
                skinToneVariants: fields[2].split(separator: " ").map(String.init)
            ))
        }
        if let category {
            sections.append(EmojiKeyboardSection(category: category, emoji: emoji))
        }
        guard sections.isEmpty == false else {
            throw EmojiDataError.invalidCatalog(line: lines.count)
        }
        self.sections = sections
    }
}
