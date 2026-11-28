import XCTest
@testable import KeyVoxPredictiveKeyboard

/// How a regional variant's folder finds its files: its own rule files only in its own folder,
/// and each data file in its own folder when it has one, else in the folder it shares data with.
final class TypingLanguageResourcesTests: XCTestCase {
    private var root: URL!
    private var bundle: Bundle!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let data = root.appendingPathComponent("PredictiveData", isDirectory: true)
        try makeFiles(in: data.appendingPathComponent("base"), files: ["rules.txt", "model.bin", "shared.bin"], folders: ["words"])
        try makeFiles(in: data.appendingPathComponent("variant"), files: ["rules.txt", "model.bin"], folders: [])
        bundle = try XCTUnwrap(Bundle(url: root))
    }

    override func tearDownWithError() throws {
        try FileManager.default.removeItem(at: root)
    }

    func testAVariantsDataFilesAreItsOwnWhereItHasThemAndTheSharedFoldersElsewhere() throws {
        let resources = try TypingLanguageResources(identifier: "variant", bundle: bundle).sharingData(withFolder: "base")
        XCTAssertEqual(try folderName(resources.dataURL("model.bin")), "variant")
        XCTAssertEqual(try folderName(resources.dataURL("shared.bin")), "base")
        XCTAssertEqual(try folderName(resources.dataDirectory("words")), "base")
        XCTAssertEqual(try resources.dataIdentifier(ofDirectory: "words"), "base")
        XCTAssertNil(resources.optionalDataURL("missing.bin"))
    }

    func testAVariantsRuleFilesComeFromItsOwnFolderAlone() throws {
        let resources = try TypingLanguageResources(identifier: "variant", bundle: bundle).sharingData(withFolder: "base")
        XCTAssertEqual(try folderName(resources.url("rules.txt")), "variant")
        XCTAssertThrowsError(try resources.url("shared.bin"))
    }

    func testALanguageSharingNoDataFindsOnlyItsOwnFiles() throws {
        let resources = try TypingLanguageResources(identifier: "variant", bundle: bundle)
        XCTAssertNil(resources.optionalDataURL("shared.bin"))
        XCTAssertThrowsError(try resources.dataDirectory("words"))
    }

    func testSharingAFolderThatIsNotBundledFails() throws {
        XCTAssertThrowsError(try TypingLanguageResources(identifier: "variant", bundle: bundle).sharingData(withFolder: "missing"))
    }

    private func folderName(_ url: URL) -> String {
        url.deletingLastPathComponent().lastPathComponent
    }

    private func makeFiles(in folder: URL, files: [String], folders: [String]) throws {
        let manager = FileManager.default
        try manager.createDirectory(at: folder, withIntermediateDirectories: true)
        for file in files {
            try Data().write(to: folder.appendingPathComponent(file))
        }
        for name in folders {
            try manager.createDirectory(at: folder.appendingPathComponent(name, isDirectory: true), withIntermediateDirectories: true)
        }
    }
}
