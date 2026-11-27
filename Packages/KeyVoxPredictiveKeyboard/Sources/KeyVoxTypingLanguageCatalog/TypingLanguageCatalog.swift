import Foundation

/// The typing languages a copy of the typing package's data holds, each with the letter layouts it
/// offers: every folder in `PredictiveData` that has a `language.json`. Reading it opens only those
/// files, never a language's dictionary or models, so a host that does not type, such as the
/// KeyVox app reading the keyboard extension's copy, can list the languages without loading them.
public struct TypingLanguageCatalog: Equatable, Sendable {
    /// The name of the typing package's resource bundle, inside the bundle of the app or extension
    /// that links it.
    public static let resourceBundleName = "KeyVoxPredictiveKeyboard_KeyVoxPredictiveKeyboard.bundle"

    /// The languages, ordered by identifier.
    public let languages: [TypingLanguageLetterLayouts]

    public init(languages: [TypingLanguageLetterLayouts]) {
        self.languages = languages.sorted { $0.identifier < $1.identifier }
    }

    /// The languages in the `PredictiveData` folder at `predictiveDataURL`. A folder whose
    /// `language.json` does not decode, or names another language, is left out.
    public init(predictiveDataURL: URL, fileManager: FileManager = .default) throws {
        let folders = try fileManager.contentsOfDirectory(
            at: predictiveDataURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )
        let decoder = JSONDecoder()
        self.init(languages: folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("language.json")),
                  let layouts = try? decoder.decode(TypingLanguageLetterLayouts.self, from: data),
                  layouts.identifier == folder.lastPathComponent else {
                return nil
            }
            return layouts
        })
    }

    /// The languages in the copy of the typing package's data inside the app or extension bundle
    /// at `bundleURL`, or nil when it holds none.
    public init?(containingBundleURL bundleURL: URL, fileManager: FileManager = .default) {
        let predictiveData = bundleURL
            .appendingPathComponent(Self.resourceBundleName, isDirectory: true)
            .appendingPathComponent("PredictiveData", isDirectory: true)
        guard let catalog = try? TypingLanguageCatalog(predictiveDataURL: predictiveData, fileManager: fileManager) else {
            return nil
        }
        self = catalog
    }

    /// The language with `identifier`, or nil when the catalog lacks it.
    public func language(_ identifier: String) -> TypingLanguageLetterLayouts? {
        languages.first { $0.identifier == identifier }
    }
}
