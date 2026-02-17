import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class ModelDownloaderTests: XCTestCase {
    func testRefreshModelStatusIsFalseWhenModelMissing() throws {
        try withTemporaryDirectory { dir in
            let downloader = makeDownloader(in: dir, minBytes: 10)

            downloader.refreshModelStatus()

            XCTAssertFalse(downloader.modelReady)
        }
    }

    func testRefreshModelStatusIsTrueWhenModelMeetsSizeThresholdAndNoZipExists() throws {
        try withTemporaryDirectory { dir in
            let downloader = makeDownloader(in: dir, minBytes: 10)
            try writeBytes(count: 12, to: downloader.modelURL)

            downloader.refreshModelStatus()

            XCTAssertTrue(downloader.modelReady)
        }
    }

    func testRefreshModelStatusIsFalseWhenModelBelowSizeThreshold() throws {
        try withTemporaryDirectory { dir in
            let downloader = makeDownloader(in: dir, minBytes: 10)
            try writeBytes(count: 5, to: downloader.modelURL)

            downloader.refreshModelStatus()

            XCTAssertFalse(downloader.modelReady)
        }
    }

    func testRefreshModelStatusIsFalseWhenCoreMLZipStillExists() throws {
        try withTemporaryDirectory { dir in
            let downloader = makeDownloader(in: dir, minBytes: 10)
            try writeBytes(count: 12, to: downloader.modelURL)
            try writeBytes(count: 1, to: coreMLZipURL(for: downloader.modelURL))

            downloader.refreshModelStatus()

            XCTAssertFalse(downloader.modelReady)
        }
    }

    func testUpdateTaskProgressAggregatesAcrossTasks() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let downloader = makeDownloader(in: dir, minBytes: 10)

        downloader.updateTaskProgress(id: 1, written: 25, total: 100)
        downloader.updateTaskProgress(id: 2, written: 50, total: 100)

        try await waitForCondition {
            abs(downloader.progress - 0.375) < 0.0001
        }
        XCTAssertEqual(downloader.progress, 0.375, accuracy: 0.0001)
    }

    func testDeleteModelRemovesArtifactsAndResetsPublishedState() async throws {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let downloader = makeDownloader(in: dir, minBytes: 10)
        try writeBytes(count: 12, to: downloader.modelURL)
        let zipURL = coreMLZipURL(for: downloader.modelURL)
        let coreMLDir = coreMLDirURL(for: downloader.modelURL)
        try writeBytes(count: 1, to: zipURL)
        try FileManager.default.createDirectory(at: coreMLDir, withIntermediateDirectories: true)

        downloader.progress = 0.9
        downloader.errorMessage = "bad state"
        downloader.modelReady = true

        downloader.deleteModel()

        try await waitForCondition {
            downloader.progress == 0 &&
            downloader.errorMessage == nil &&
            downloader.modelReady == false
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: downloader.modelURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: zipURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: coreMLDir.path))
    }

    private func makeDownloader(in directory: URL, minBytes: Int64) -> ModelDownloader {
        let modelURL = directory
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("ggml-base.bin")

        return ModelDownloader(
            fileManager: FileManager.default,
            modelURLOverride: modelURL,
            minGGMLBytes: minBytes,
            refreshOnInit: false
        )
    }

    private func coreMLZipURL(for modelURL: URL) -> URL {
        modelURL.deletingPathExtension().appendingPathExtension("encoder.mlmodelc.zip")
    }

    private func coreMLDirURL(for modelURL: URL) -> URL {
        modelURL.deletingPathExtension().appendingPathExtension("encoder.mlmodelc")
    }

    private func writeBytes(count: Int, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = Data(repeating: 0x61, count: count)
        try data.write(to: url)
    }

    private func makeTempDirectory() -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("KeyVoxTests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}
