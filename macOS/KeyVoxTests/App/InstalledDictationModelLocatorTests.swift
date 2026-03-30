import Foundation
import XCTest
@testable import KeyVox

final class InstalledDictationModelLocatorTests: XCTestCase {
    func testWhisperModelPathPreservesExistingRootLocation() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(tempDirectoryURL) }

        let locator = InstalledDictationModelLocator(
            fileManager: .default,
            appSupportRootURL: tempDirectoryURL
        )
        try FileManager.default.createDirectory(at: locator.modelsRootURL, withIntermediateDirectories: true)
        try Data([0x01]).write(to: locator.whisperModelURL, options: .atomic)

        XCTAssertEqual(locator.whisperModelURL.lastPathComponent, "ggml-base.bin")
        XCTAssertEqual(locator.whisperModelURL.deletingLastPathComponent(), locator.modelsRootURL)
        XCTAssertEqual(locator.resolvedWhisperModelPath(), locator.whisperModelURL.path)
    }

    func testParakeetModelDirectoryResolvesInsideModelsFolder() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(tempDirectoryURL) }

        let locator = InstalledDictationModelLocator(
            fileManager: .default,
            appSupportRootURL: tempDirectoryURL
        )
        try writeStrictManifestInstall(for: .parakeetTdtV3, using: locator)

        XCTAssertEqual(locator.parakeetModelDirectoryURL.lastPathComponent, "parakeet")
        XCTAssertEqual(locator.parakeetModelDirectoryURL.deletingLastPathComponent(), locator.modelsRootURL)
        XCTAssertEqual(locator.resolvedParakeetModelDirectoryURL(), locator.parakeetModelDirectoryURL)
    }

    func testParakeetResolverFailsClosedWhenManifestIsMissing() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(tempDirectoryURL) }

        let locator = InstalledDictationModelLocator(
            fileManager: .default,
            appSupportRootURL: tempDirectoryURL
        )
        try FileManager.default.createDirectory(
            at: locator.parakeetModelDirectoryURL,
            withIntermediateDirectories: true
        )

        for artifact in DictationModelCatalog.descriptor(for: .parakeetTdtV3).artifacts {
            let url = locator.installedArtifactURL(for: .parakeetTdtV3, relativePath: artifact.relativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data([0x01]).write(to: url, options: .atomic)
        }

        XCTAssertNil(locator.resolvedParakeetModelDirectoryURL())
    }

    func testResolversFailClosedWhenArtifactsAreMissing() throws {
        let tempDirectoryURL = try makeTemporaryDirectory()
        defer { removeTemporaryDirectory(tempDirectoryURL) }

        let locator = InstalledDictationModelLocator(
            fileManager: .default,
            appSupportRootURL: tempDirectoryURL
        )

        XCTAssertNil(locator.resolvedWhisperModelPath())
        XCTAssertNil(locator.resolvedParakeetModelDirectoryURL())
    }

    private func makeTemporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("InstalledDictationModelLocatorTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func removeTemporaryDirectory(_ url: URL) {
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func writeStrictManifestInstall(
        for modelID: DictationModelID,
        using locator: InstalledDictationModelLocator
    ) throws {
        let descriptor = locator.descriptor(for: modelID)
        try FileManager.default.createDirectory(
            at: locator.installRootURL(for: modelID),
            withIntermediateDirectories: true
        )

        var hashes: [String: String] = [:]
        for artifact in descriptor.artifacts {
            let url = locator.installedArtifactURL(for: modelID, relativePath: artifact.relativePath)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try Data([0x01]).write(to: url, options: .atomic)
            hashes[artifact.relativePath] = artifact.expectedSHA256
        }

        let manifest = DictationModelInstallManifest(
            version: DictationModelInstallManifest.currentVersion,
            artifactSHA256ByRelativePath: hashes
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(
            to: locator.manifestURL(for: modelID)!,
            options: .atomic
        )
    }
}
