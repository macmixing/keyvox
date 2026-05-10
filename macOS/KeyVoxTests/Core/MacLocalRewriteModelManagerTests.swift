import CryptoKit
import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class MacLocalRewriteModelManagerTests: XCTestCase {
    func testSuccessfulDownloadWritesArtifactAndManifest() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Data("local model".utf8)
        let descriptor = descriptor(expectedSHA256: sha256Hex(payload))
        let manager = MacLocalRewriteModelManager(
            appSupportRootURL: directory,
            descriptor: descriptor,
            download: downloadReturning(payload, in: directory)
        )

        manager.downloadModel()
        let installTask = try XCTUnwrap(manager.installTask)
        await installTask.value

        XCTAssertEqual(manager.installState, .ready)
        XCTAssertTrue(manager.isModelReady())
        let installedURL = try XCTUnwrap(manager.installedModelURL())
        XCTAssertEqual(try Data(contentsOf: installedURL), payload)
        XCTAssertTrue(
            FileManager.default.fileExists(
                atPath: directory
                    .appendingPathComponent("Models/rewrite/test-vibes-model/install-manifest.json")
                    .path
            )
        )
    }

    func testSHA256MismatchFailsDeterministically() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let manager = MacLocalRewriteModelManager(
            appSupportRootURL: directory,
            descriptor: descriptor(expectedSHA256: sha256Hex(Data("expected".utf8))),
            download: downloadReturning(Data("actual".utf8), in: directory)
        )

        manager.downloadModel()
        let installTask = try XCTUnwrap(manager.installTask)
        await installTask.value

        XCTAssertFalse(manager.isModelReady())
        XCTAssertEqual(manager.errorMessage, MacVibesSettingsCopy.integrityCheckFailed)
    }

    func testDeleteModelInvalidatesInstalledModel() async throws {
        let directory = makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let payload = Data("local model".utf8)
        let manager = MacLocalRewriteModelManager(
            appSupportRootURL: directory,
            descriptor: descriptor(expectedSHA256: sha256Hex(payload)),
            download: downloadReturning(payload, in: directory)
        )
        var didInvalidate = false
        manager.onDidInvalidateInstalledModel = {
            didInvalidate = true
        }
        manager.downloadModel()
        let installTask = try XCTUnwrap(manager.installTask)
        await installTask.value

        manager.deleteModel()

        XCTAssertTrue(didInvalidate)
        XCTAssertFalse(manager.isModelReady())
        XCTAssertNil(manager.installedModelURL())
    }

    private func descriptor(expectedSHA256: String) -> MacLocalRewriteModelDescriptor {
        MacLocalRewriteModelDescriptor(
            id: "test-vibes-model",
            displayName: "Test Vibes Model",
            sourceRepository: "Test/Model",
            artifact: MacLocalRewriteModelArtifact(
                filename: "test-vibes-model.gguf",
                remoteURL: URL(string: "https://example.com/test-vibes-model.gguf")!,
                expectedSHA256: expectedSHA256,
                progressTotalBytes: 11
            )
        )
    }

    private func downloadReturning(
        _ data: Data,
        in directory: URL
    ) -> MacLocalRewriteModelManager.DownloadClosure {
        { _, progress in
            progress(.complete)
            let url = directory
                .appendingPathComponent("download-\(UUID().uuidString)", isDirectory: false)
            try data.write(to: url, options: .atomic)
            return url
        }
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeTemporaryDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacLocalRewriteModelManagerTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
