import Foundation
import KeyVoxTypingLanguageCatalog
import Testing
@testable import KeyVox_iOS

/// Every letter layout the keyboard bundles is shown by a name written for it, and no two layouts
/// share a name, so the Layout menu never lists the same name twice.
struct KeyboardLetterLayoutNameTests {
    @Test func everyBundledLayoutHasItsOwnName() throws {
        let identifiers = try bundledLayoutIdentifiers()
        #expect(identifiers.isEmpty == false)

        let names = identifiers.compactMap(KeyboardLetterLayoutName.systemName(for:))
        #expect(names.count == identifiers.count)
        #expect(Set(names).count == names.count)
    }

    @Test func aLayoutWithoutANameShowsItsIdentifier() {
        let identifier = UUID().uuidString
        #expect(KeyboardLetterLayoutName.systemName(for: identifier) == nil)
        #expect(KeyboardLetterLayoutName.displayName(for: identifier) == identifier)
    }

    /// The layouts in the keyboard extension's copy of the typing data, by their file names.
    private func bundledLayoutIdentifiers() throws -> [String] {
        let plugIns = try #require(Bundle.main.builtInPlugInsURL)
        let extensions = try FileManager.default.contentsOfDirectory(at: plugIns, includingPropertiesForKeys: nil)
        let layouts = try #require(extensions.lazy.compactMap { bundle -> [URL]? in
            try? FileManager.default.contentsOfDirectory(
                at: bundle
                    .appendingPathComponent(TypingLanguageCatalog.resourceBundleName, isDirectory: true)
                    .appendingPathComponent("PredictiveData/letter_layouts", isDirectory: true),
                includingPropertiesForKeys: nil
            )
        }.first)
        return layouts.map { $0.deletingPathExtension().lastPathComponent }
    }
}
