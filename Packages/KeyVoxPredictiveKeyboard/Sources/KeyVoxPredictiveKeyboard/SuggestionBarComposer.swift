/// Chooses the three suggestion-bar items.
///
/// While a word is being typed: the typed letters, the autocorrection space will apply
/// (or else the best-ranked word), and the next best word. Between words: the three most
/// likely next words.
public enum SuggestionBarComposer {
    public static func compose(
        typedWord: String,
        autocorrection: String?,
        rankedWords: [String]
    ) -> SuggestionBar {
        let others = rankedWords.filter {
            $0.caseInsensitiveCompare(typedWord) != .orderedSame
                && $0.caseInsensitiveCompare(autocorrection ?? "") != .orderedSame
        }
        let typed = SuggestionBar.Item(text: typedWord, kind: .typed)
        if let autocorrection {
            return SuggestionBar(
                primary: SuggestionBar.Item(text: autocorrection, kind: .autocorrection),
                leading: typed,
                trailing: others.first.map { SuggestionBar.Item(text: $0, kind: .suggestion) }
            )
        }
        return SuggestionBar(
            primary: others.first.map { SuggestionBar.Item(text: $0, kind: .suggestion) },
            leading: typed,
            trailing: others.dropFirst().first.map { SuggestionBar.Item(text: $0, kind: .suggestion) }
        )
    }

    public static func composeNextWords(_ rankedWords: [String]) -> SuggestionBar {
        let items = rankedWords.prefix(3).map { SuggestionBar.Item(text: $0, kind: .nextWord) }
        return SuggestionBar(
            primary: items.first,
            leading: items.dropFirst().first,
            trailing: items.dropFirst(2).first
        )
    }
}
