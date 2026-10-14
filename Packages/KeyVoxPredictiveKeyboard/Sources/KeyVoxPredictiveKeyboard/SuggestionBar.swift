/// What the suggestion bar offers, by role rather than screen position.
public struct SuggestionBar: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// The letters exactly as typed, so the user can keep them.
        case typed
        /// The word space will insert instead of the typed letters.
        case autocorrection
        case suggestion
        case nextWord
        /// What was typed before the autocorrection right before the cursor, which tapping puts
        /// back.
        case revert
        /// An emoji for the word the bar is for, which tapping types in place of that word, or
        /// after it when a space already follows it.
        case emoji
    }

    public struct Item: Sendable, Equatable {
        public let text: String
        public let kind: Kind

        public init(text: String, kind: Kind) {
            self.text = text
            self.kind = kind
        }
    }

    /// The most likely choice, if any.
    public let primary: Item?
    /// The typed letters while a word is in progress, otherwise another prediction.
    public let leading: Item?
    public let trailing: Item?
    /// Emoji for the word the bar is for, shown in place of `trailing`, as on the system keyboard.
    public let emoji: [Item]

    public static let empty = SuggestionBar(primary: nil, leading: nil, trailing: nil)

    public init(primary: Item?, leading: Item?, trailing: Item?, emoji: [Item] = []) {
        self.primary = primary
        self.leading = leading
        self.trailing = trailing
        self.emoji = emoji
    }

    public var items: [Item] {
        [leading, primary, trailing].compactMap { $0 } + emoji
    }

    /// This bar with `emoji` in place of its trailing item, or as it is when there are none.
    public func showing(emoji: [String]) -> SuggestionBar {
        guard emoji.isEmpty == false else { return self }
        return SuggestionBar(
            primary: primary,
            leading: leading,
            trailing: nil,
            emoji: emoji.map { Item(text: $0, kind: .emoji) }
        )
    }
}
