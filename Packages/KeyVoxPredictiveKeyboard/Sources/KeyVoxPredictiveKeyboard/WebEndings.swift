import Foundation

/// The web endings a web address field's key types and offers when held, as Apple's keyboard
/// chooses them, from the lists Apple's keyboard files give each locale
/// (`PredictiveData/web_endings.json`, written by `Tools/AppleKeyboardBaseline/write_web_endings.py`).
///
/// Measured on the iOS 27.2 simulator: the key types the first ending of the device region's
/// list, which sits over the key, and the region's other endings alternate to its right and left,
/// the right holding `endingsRightOfKey` of them. Farther left come, nearest first, the endings of
/// the device's languages' lists that the region's lacks, but for each list's own country ending,
/// then every ending of the keyboard's languages' lists that the popup lacks.
public struct WebEndings: Sendable {
    /// What a web address field's key types, and what holding it offers.
    public struct Offer: Sendable, Equatable {
        /// The ending the key types.
        public let ending: String
        /// The endings left to right, the key's own over the key (`HeldKeyCharacters.Direction.centered`).
        public let held: HeldKeyCharacters.Offer
    }

    private struct File: Decodable {
        let endingsRightOfKey: Int
        let locales: [String: [String]]
    }

    private let endingsRightOfKey: Int
    private let locales: [String: [String]]

    /// The bundled endings.
    public static func bundled() throws -> WebEndings {
        guard let data = KeyVoxPredictiveKeyboardResources.bundle.url(forResource: "PredictiveData", withExtension: nil) else {
            throw PredictiveKeyboardError.missingArtifact("PredictiveData")
        }
        return try WebEndings(contentsOf: data.appendingPathComponent(fileName, isDirectory: false))
    }

    static let fileName = "web_endings.json"

    init(contentsOf url: URL) throws {
        let file: File
        do {
            file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        } catch {
            throw PredictiveKeyboardError.missingArtifact(Self.fileName)
        }
        endingsRightOfKey = file.endingsRightOfKey
        locales = file.locales.filter { $0.value.isEmpty == false }
    }

    /// The offer for a device in `region` (a region code, such as `US`) whose languages are
    /// `preferredLanguages` (language identifiers, such as `en-US`, preferred first), on a
    /// keyboard typing `languages`, the one it types in first; nil when no list is known for any
    /// of them.
    public func offer(region: String?, preferredLanguages: [String], languages: [TypingLanguage]) -> Offer? {
        let keyboardLocales = languages.map(\.webEndingsLocale)
        let languageLocales = preferredLanguages.map { $0.replacingOccurrences(of: "-", with: "_") }
        guard let regionEndings = regionEndings(
            region: region,
            languageCodes: languageLocales.map(Self.languageCode) + keyboardLocales.map(Self.languageCode)
        ) ?? keyboardLocales.lazy.compactMap({ self.locales[$0] }).first,
              let ending = regionEndings.first else {
            return nil
        }
        var right: [String] = []
        var left: [String] = []
        for (index, other) in regionEndings.dropFirst().enumerated() {
            if index.isMultiple(of: 2), right.count < endingsRightOfKey {
                right.append(other)
            } else {
                left.append(other)
            }
        }
        var shown = Set(regionEndings)
        let languageEndings = languageLocales.flatMap { locale in
            (locales[locale] ?? []).filter { $0 != Self.countryEnding(of: locale) }
        }
        let keyboardEndings = keyboardLocales.flatMap { locales[$0] ?? [] }
        for other in languageEndings + keyboardEndings where shown.insert(other).inserted {
            left.append(other)
        }
        return Offer(
            ending: ending,
            held: HeldKeyCharacters.Offer(characters: left.reversed() + [ending] + right, direction: .centered, ownIndex: left.count)
        )
    }

    /// The list of the locale in `region`, of the first of `languageCodes` that has one there, or
    /// else of the region's likeliest language (the system's likely-subtags data), or else of the
    /// first locale in the region by its identifier.
    private func regionEndings(region: String?, languageCodes: [String]) -> [String]? {
        guard let region else { return nil }
        let likely = Locale.Language(identifier: "und-\(region)").maximalIdentifier
        for code in languageCodes + [Self.languageCode(likely.replacingOccurrences(of: "-", with: "_"))] {
            if let endings = locales["\(code)_\(region)"] { return endings }
        }
        return locales.keys.sorted().first { Self.region(of: $0) == region }.flatMap { locales[$0] }
    }

    private static func languageCode(_ locale: String) -> String {
        String(locale.prefix { $0 != "_" })
    }

    private static func region(of locale: String) -> String? {
        let parts = locale.split(separator: "_")
        return parts.count > 1 ? String(parts[parts.count - 1]) : nil
    }

    /// The ending named for the locale's region, such as `.us` for `en_US`.
    private static func countryEnding(of locale: String) -> String? {
        region(of: locale).map { "." + $0.lowercased() }
    }
}
