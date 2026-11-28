import Foundation
import XCTest
@testable import KeyVoxEmoji

/// Each typing language's emoji data: a language reads its own folder, a regional variant without
/// one reads its language's, and every bundled language's data loads and names catalog emoji.
final class EmojiLanguageDataTests: XCTestCase {
    func testALanguageReadsItsOwnData() throws {
        let locator = try Self.locator(folders: ["fr", "fr-CA"])
        XCTAssertEqual(try locator.url(name: "data", extension: "txt", language: "fr").deletingLastPathComponent().lastPathComponent, "fr")
        XCTAssertEqual(try locator.url(name: "data", extension: "txt", language: "fr-CA").deletingLastPathComponent().lastPathComponent, "fr-CA")
    }

    func testAVariantWithoutItsOwnReadsItsLanguages() throws {
        let locator = try Self.locator(folders: ["es"])
        XCTAssertEqual(try locator.url(name: "data", extension: "txt", language: "es-419").deletingLastPathComponent().lastPathComponent, "es")
    }

    func testALanguageWithoutDataHasNone() throws {
        let locator = try Self.locator(folders: ["es"])
        XCTAssertThrowsError(try locator.url(name: "data", extension: "txt", language: "esx")) { error in
            XCTAssertEqual(error as? EmojiDataError, .missingData("esx/data.txt"))
        }
    }

    func testEveryBundledLanguageOffersAndFindsOnlyCatalogEmoji() throws {
        let languages = try Self.bundledLanguages()
        XCTAssertFalse(languages.isEmpty)
        let catalog = Set(try EmojiCatalog.bundled().sections.flatMap(\.emoji).map(\.text))
        for language in languages {
            for name in ["emoji_predictions", "emoji_search"] {
                let url = try EmojiDataLocator().url(name: name, extension: "txt", language: language)
                for line in try String(contentsOf: url, encoding: .utf8).split(separator: "\n") {
                    let fields = line.split(separator: "\t")
                    let emoji = name == "emoji_search" ? [fields[0]] : fields[1].split(separator: " ")
                    for text in emoji {
                        XCTAssertTrue(catalog.contains(String(text)), "\(language) \(name) \(fields[0])")
                    }
                }
            }
            XCTAssertNoThrow(try EmojiPredictions.bundled(language: language), language)
            XCTAssertNoThrow(try EmojiSearch.bundled(language: language), language)
        }
    }

    /// The languages the package bundles data for: the folders of its emoji data.
    private static func bundledLanguages() throws -> [String] {
        let catalog = try EmojiDataLocator().url(name: "emoji_catalog", extension: "txt")
        return try FileManager.default.contentsOfDirectory(
            at: catalog.deletingLastPathComponent(),
            includingPropertiesForKeys: [.isDirectoryKey]
        ).filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .map(\.lastPathComponent)
            .sorted()
    }

    /// A locator over a bundle holding `EmojiData/<folder>/data.txt` for each of `folders`.
    private static func locator(folders: [String]) throws -> EmojiDataLocator {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        for folder in folders {
            let directory = root.appendingPathComponent("EmojiData/\(folder)", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try "x".write(to: directory.appendingPathComponent("data.txt"), atomically: true, encoding: .utf8)
        }
        guard let bundle = Bundle(url: root) else { throw EmojiDataError.missingData(root.path) }
        return EmojiDataLocator(bundle: bundle)
    }
}
