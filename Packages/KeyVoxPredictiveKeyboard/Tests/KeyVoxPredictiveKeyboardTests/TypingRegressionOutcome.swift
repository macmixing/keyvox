import KeyVoxPredictiveKeyboard
import KeyVoxTypingSimulation

/// What typing one regression case gave, as `expected.jsonl` records it: the text left once
/// every word was typed and a space tapped after it, and each recorded suggestion bar slot by
/// slot, as the keyboard draws it, an empty slot recorded as empty, with its emoji.
struct TypingRegressionOutcome: Codable, Equatable {
    struct Item: Codable, Equatable {
        let kind: String
        let text: String

        init(_ item: SuggestionBar.Item) {
            kind = TypingRegressionOutcome.name(of: item.kind)
            text = item.text
        }
    }

    struct Bar: Codable, Equatable {
        let leading: Item?
        let primary: Item?
        let trailing: Item?
        let emoji: [Item]

        init(_ bar: SuggestionBar) {
            leading = bar.leading.map(Item.init)
            primary = bar.primary.map(Item.init)
            trailing = bar.trailing.map(Item.init)
            emoji = bar.emoji.map(Item.init)
        }

        /// Writes an empty slot as null rather than leaving it out.
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(leading, forKey: .leading)
            try container.encode(primary, forKey: .primary)
            try container.encode(trailing, forKey: .trailing)
            try container.encode(emoji, forKey: .emoji)
        }
    }

    let text: String
    let bars: [Bar]

    init(_ typed: SessionTyper.TypedSentence) {
        text = typed.text
        bars = typed.bars.map(Bar.init)
    }

    fileprivate static func name(of kind: SuggestionBar.Kind) -> String {
        switch kind {
        case .typed: return "typed"
        case .autocorrection: return "autocorrection"
        case .suggestion: return "suggestion"
        case .nextWord: return "nextWord"
        case .revert: return "revert"
        case .emoji: return "emoji"
        }
    }
}
