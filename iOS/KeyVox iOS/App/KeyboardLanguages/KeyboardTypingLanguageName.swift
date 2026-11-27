import Foundation

/// The names a typing language is shown by, from `Locale` in the language the app or keyboard is
/// shown in: its full name, with its region in parentheses for a regional variant.
nonisolated enum KeyboardTypingLanguageName {
    /// The language `identifier` names, such as `fr-CA`, written in `locale`'s language and
    /// starting with a capital letter, since it stands alone in lists.
    static func displayName(for identifier: String, locale: Locale = shownLocale) -> String {
        guard let name = locale.localizedString(forIdentifier: identifier), let first = name.first else {
            return identifier
        }
        return String(first).uppercased(with: locale) + name.dropFirst()
    }

    /// The language the running app or extension shows its text in.
    static var shownLocale: Locale {
        Bundle.main.preferredLocalizations.first.map(Locale.init(identifier:)) ?? .current
    }
}
