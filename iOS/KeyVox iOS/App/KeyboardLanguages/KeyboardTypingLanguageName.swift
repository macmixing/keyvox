import Foundation

/// The names a typing language is shown by: its full name from `Locale` in the language the app or
/// keyboard is shown in, with its region in parentheses for a regional variant, and its short code.
/// Shared by the KeyVox app and the keyboard extension.
nonisolated enum KeyboardTypingLanguageName {
    /// The language `identifier` names, such as `fr-CA`, written in `locale`'s language and
    /// starting with a capital letter, since it stands alone in lists.
    static func displayName(for identifier: String, locale: Locale = shownLocale) -> String {
        guard let name = locale.localizedString(forIdentifier: identifier), let first = name.first else {
            return identifier
        }
        return String(first).uppercased(with: locale) + name.dropFirst()
    }

    /// The short code the space bar shows for `identifier`: its language code in capitals, such as
    /// `EN`, followed by its region, such as `FR CA`, only when another of `identifiers` has the same
    /// language code and the region is a single country. A region made of several countries, such
    /// as Latin America's `419`, adds nothing, as Apple's keyboard for it shows only its language.
    static func shortCode(for identifier: String, among identifiers: [String]) -> String {
        let language = Locale.Language(identifier: identifier)
        let code = (language.languageCode?.identifier ?? identifier).uppercased()
        let sharesCode = identifiers.contains { other in
            other != identifier && Locale.Language(identifier: other).languageCode == language.languageCode
        }
        guard sharesCode, let region = language.region, region.subRegions.isEmpty else { return code }
        return code + " " + region.identifier.uppercased()
    }

    /// The language the running app or extension shows its text in.
    static var shownLocale: Locale {
        Bundle.main.preferredLocalizations.first.map(Locale.init(identifier:)) ?? .current
    }
}
