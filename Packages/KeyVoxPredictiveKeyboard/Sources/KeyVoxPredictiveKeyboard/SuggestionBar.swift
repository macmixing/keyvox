/// What the suggestion bar offers, by role rather than screen position.
public struct SuggestionBar: Sendable, Equatable {
    public enum Kind: Sendable, Equatable {
        /// The letters exactly as typed, so the user can keep them.
        case typed
        /// The word space will insert instead of the typed letters.
        case autocorrection
        case suggestion
        case nextWord
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

    public static let empty = SuggestionBar(primary: nil, leading: nil, trailing: nil)

    public init(primary: Item?, leading: Item?, trailing: Item?) {
        self.primary = primary
        self.leading = leading
        self.trailing = trailing
    }

    public var items: [Item] {
        [leading, primary, trailing].compactMap { $0 }
    }
}
