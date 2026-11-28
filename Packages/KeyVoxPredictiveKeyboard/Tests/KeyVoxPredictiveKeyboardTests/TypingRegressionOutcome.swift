import KeyVoxPredictiveKeyboard
import KeyVoxTypingSimulation

/// What typing one regression case gave, as `expected.jsonl` records it: the text left once
/// every word was typed and a space tapped after it, and each recorded suggestion bar's items
/// in the order the bar shows them.
struct TypingRegressionOutcome: Codable, Equatable {
    struct Item: Codable, Equatable {
        let kind: String
        let text: String
    }

    let text: String
    let bars: [[Item]]

    init(_ typed: SessionTyper.TypedSentence) {
        text = typed.text
        bars = typed.bars.map { bar in
            bar.items.map { Item(kind: Self.name(of: $0.kind), text: $0.text) }
        }
    }

    private static func name(of kind: SuggestionBar.Kind) -> String {
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
