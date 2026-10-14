/// One category of the emoji keyboard and the emoji it shows, in order.
public struct EmojiKeyboardSection: Sendable, Equatable {
    public let category: EmojiKeyboardCategory
    public let emoji: [Emoji]

    public init(category: EmojiKeyboardCategory, emoji: [Emoji]) {
        self.category = category
        self.emoji = emoji
    }
}
