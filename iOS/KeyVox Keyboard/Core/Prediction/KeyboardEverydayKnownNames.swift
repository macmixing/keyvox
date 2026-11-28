import KeyVoxPredictiveKeyboard

/// Which of the user's known names are everyday words of any of the typing languages they selected
/// (`EverydayKnownNames`), worked out again only when the names or the selected languages change,
/// so each new field and each change of language reuses the last answer. Use from one queue.
final class KeyboardEverydayKnownNames {
    private var latest: (knownNames: [String], typingLanguages: [String], names: EverydayKnownNames)?

    /// - Parameter typingLanguages: The identifiers of the languages the user selected.
    func resolved(knownNames: [String], typingLanguages: [String]) -> EverydayKnownNames {
        if let latest, latest.knownNames == knownNames, latest.typingLanguages == typingLanguages {
            return latest.names
        }
        let languages = typingLanguages.compactMap { try? TypingLanguage.bundled(identifier: $0) }
        let names = (try? EverydayKnownNames(knownNames: knownNames, languages: languages)) ?? .none
        latest = (knownNames, typingLanguages, names)
        return names
    }
}
