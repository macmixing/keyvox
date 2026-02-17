import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class ModelDownloaderTests: XCTestCase {
    func testRefreshOnInitTrueHydratesModelReady() throws {
        try withTemporaryDirectory { dir in
            let modelURL = dir
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent("ggml-base.bin")
            try writeBytes(count: 12, to: modelURL)

            let downloader = ModelDownloader(
                fileManager: FileManager.default,
                modelURLOverride: modelURL,
                minGGMLBytes: 10,
                refreshOnInit: true
            )

            XCTAssertTrue(downloader.modelReady)
        }
    }

    func testRefreshOnInitFalseLeavesDefaultModelReadyStateUntilRefresh() throws {
        try withTemporaryDirectory { dir in
            let modelURL = dir
                .appendingPathComponent("Models", isDirectory: true)
                .appendingPathComponent("ggml-base.bin")
            try writeBytes(count: 12, to: modelURL)

            let downloader = ModelDownloader(
                fileManager: FileManager.default,
                modelURLOverride: modelURL,
                minGGMLBytes: 10,
                refreshOnInit: false
            )

            XCTAssertFalse(downloader.modelReady)
            downloader.refreshModelStatus()
            XCTAssertTrue(downloader.modelReady)
        }
    }

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

    func testDownloadBaseModelInitializesTaskProgressAndResumesTasks() {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sessionFactory = RecordingSessionFactory(taskIDs: [101, 202])
        let downloader = makeDownloader(
            in: dir,
            minBytes: 10,
            makeDownloadSession: sessionFactory.makeSession(delegate:)
        )

        downloader.downloadBaseModel()

        XCTAssertTrue(downloader.isDownloading)
        XCTAssertEqual(downloader.progress, 0, accuracy: 0.0001)
        XCTAssertNil(downloader.errorMessage)
        XCTAssertEqual(sessionFactory.makeCount, 1)
        XCTAssertEqual(sessionFactory.createdSession.downloadURLs.count, 2)
        XCTAssertEqual(sessionFactory.createdSession.tasks[0].resumeCalls, 1)
        XCTAssertEqual(sessionFactory.createdSession.tasks[1].resumeCalls, 1)

        let snapshot = downloader.taskProgressSnapshot
        XCTAssertEqual(snapshot[101]?.written, 0)
        XCTAssertEqual(snapshot[101]?.total, 140_000_000)
        XCTAssertEqual(snapshot[202]?.written, 0)
        XCTAssertEqual(snapshot[202]?.total, 50_000_000)
    }

    func testDownloadBaseModelIsGuardedWhenAlreadyDownloading() {
        let dir = makeTempDirectory()
        defer { try? FileManager.default.removeItem(at: dir) }

        let sessionFactory = RecordingSessionFactory(taskIDs: [301, 302])
        let downloader = makeDownloader(
            in: dir,
            minBytes: 10,
            makeDownloadSession: sessionFactory.makeSession(delegate:)
        )

        downloader.downloadBaseModel()
        downloader.downloadBaseModel()

        XCTAssertEqual(sessionFactory.makeCount, 1)
        XCTAssertEqual(sessionFactory.createdSession.downloadURLs.count, 2)
    }

    private func makeDownloader(
        in directory: URL,
        minBytes: Int64,
        makeDownloadSession: @escaping ModelDownloader.SessionFactory = { delegate in
            RecordingSessionFactory(taskIDs: [1, 2]).makeSession(delegate: delegate)
        }
    ) -> ModelDownloader {
        let modelURL = directory
            .appendingPathComponent("Models", isDirectory: true)
            .appendingPathComponent("ggml-base.bin")

        return ModelDownloader(
            fileManager: FileManager.default,
            modelURLOverride: modelURL,
            minGGMLBytes: minBytes,
            refreshOnInit: false,
            makeDownloadSession: makeDownloadSession
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

private final class RecordingSessionFactory {
    private let taskIDs: [Int]
    private(set) var makeCount = 0
    private(set) var createdSession: RecordingDownloadSession!

    init(taskIDs: [Int]) {
        self.taskIDs = taskIDs
    }

    func makeSession(delegate: URLSessionDownloadDelegate) -> ModelDownloadSessioning {
        _ = delegate
        makeCount += 1
        createdSession = RecordingDownloadSession(taskIDs: taskIDs)
        return createdSession
    }
}

private final class RecordingDownloadSession: ModelDownloadSessioning {
    private let taskIDs: [Int]
    private var nextIndex = 0
    private(set) var downloadURLs: [URL] = []
    private(set) var tasks: [RecordingDownloadTask] = []

    init(taskIDs: [Int]) {
        self.taskIDs = taskIDs
    }

    func downloadTask(with url: URL) -> ModelDownloadTasking {
        downloadURLs.append(url)
        let task = RecordingDownloadTask(taskIdentifier: taskIDs[nextIndex])
        nextIndex += 1
        tasks.append(task)
        return task
    }
}

private final class RecordingDownloadTask: ModelDownloadTasking {
    let taskIdentifier: Int
    private(set) var resumeCalls = 0

    init(taskIdentifier: Int) {
        self.taskIdentifier = taskIdentifier
    }

    func resume() {
        resumeCalls += 1
    }
}
