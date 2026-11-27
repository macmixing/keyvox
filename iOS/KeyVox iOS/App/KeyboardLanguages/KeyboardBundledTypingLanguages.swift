import Foundation
import KeyVoxTypingLanguageCatalog

/// The typing languages the KeyVox keyboard bundles, with the letter layouts each offers. The app
/// does not bundle the typing data itself, so it reads the keyboard extension's copy.
enum KeyboardBundledTypingLanguages {
    static let catalog: TypingLanguageCatalog = {
        guard let plugIns = Bundle.main.builtInPlugInsURL,
              let extensions = try? FileManager.default.contentsOfDirectory(
                  at: plugIns,
                  includingPropertiesForKeys: nil,
                  options: [.skipsHiddenFiles]
              ) else {
            return TypingLanguageCatalog(languages: [])
        }
        return extensions.lazy.compactMap { TypingLanguageCatalog(containingBundleURL: $0) }.first
            ?? TypingLanguageCatalog(languages: [])
    }()
}
