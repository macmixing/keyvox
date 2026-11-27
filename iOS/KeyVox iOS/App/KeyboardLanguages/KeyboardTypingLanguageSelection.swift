import Foundation
import KeyVoxTypingLanguageCatalog

/// The languages the KeyVox keyboard types in, in the order its space bar switches through them,
/// each with its letter layout: what the user saved in the KeyVox app, kept to the languages the
/// keyboard bundles. Nothing saved, or nothing saved the keyboard still bundles, gives the bundled
/// language the app was written in, or the first bundled language when it lacks that one. A saved
/// layout the language does not offer gives the language's default layout.
nonisolated struct KeyboardTypingLanguageSelection: Equatable {
    /// One selected language.
    struct Language: Equatable {
        /// The typing language's identifier, such as `en`.
        let identifier: String
        /// The letter layout the keyboard shows for it.
        let letterLayout: String
        /// Every layout the language offers, in Apple's order: the default first.
        let letterLayouts: [String]
    }

    let languages: [Language]

    /// - Parameters:
    ///   - savedLanguages: The language identifiers the user saved, in space-bar order.
    ///   - savedLetterLayouts: The layout the user saved for each language, by identifier.
    ///   - catalog: The languages the keyboard bundles.
    ///   - fallbackLanguage: The language to type in when nothing saved is bundled, such as the
    ///     language the app was written in.
    init(
        savedLanguages: [String],
        savedLetterLayouts: [String: String],
        catalog: TypingLanguageCatalog,
        fallbackLanguage: String?
    ) {
        var seen = Set<String>()
        var chosen = savedLanguages.compactMap { identifier -> TypingLanguageLetterLayouts? in
            guard seen.insert(identifier).inserted else { return nil }
            return catalog.language(identifier)
        }
        if chosen.isEmpty, let fallback = Self.fallback(fallbackLanguage, in: catalog) {
            chosen = [fallback]
        }
        languages = chosen.map { language in
            let saved = savedLetterLayouts[language.identifier]
            return Language(
                identifier: language.identifier,
                letterLayout: saved.flatMap { language.letterLayouts.contains($0) ? $0 : nil }
                    ?? language.defaultLetterLayout,
                letterLayouts: language.letterLayouts
            )
        }
    }

    /// The identifiers of the selected languages, in space-bar order.
    var identifiers: [String] {
        languages.map(\.identifier)
    }

    private static func fallback(_ identifier: String?, in catalog: TypingLanguageCatalog) -> TypingLanguageLetterLayouts? {
        if let identifier {
            if let exact = catalog.language(identifier) {
                return exact
            }
            let languageCode = Locale.Language(identifier: identifier).languageCode
            if let sameLanguage = catalog.languages.first(where: {
                Locale.Language(identifier: $0.identifier).languageCode == languageCode
            }) {
                return sameLanguage
            }
        }
        return catalog.languages.first
    }
}
