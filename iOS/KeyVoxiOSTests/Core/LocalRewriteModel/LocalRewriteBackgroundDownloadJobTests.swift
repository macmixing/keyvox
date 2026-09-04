import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct LocalRewriteBackgroundDownloadJobTests {
    @Test func jobRoundTripsThroughPersistentStore() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let jobURL = rootURL.appendingPathComponent("background-download-job.json")
        let store = LocalRewriteBackgroundDownloadJobStore(
            fileManager: .default,
            jobURLProvider: { jobURL }
        )
        var job = LocalRewriteBackgroundDownloadJob(descriptor: LocalRewriteModelCatalog.descriptor)
        job.phase = .downloading
        job.completedBytes = 123_456_789

        try store.save(job)

        #expect(store.load() == job)
    }

    @Test func persistedProgressDoesNotRegressWhenDestinationTaskStartsLower() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let jobURL = rootURL.appendingPathComponent("background-download-job.json")
        let stagingURL = rootURL.appendingPathComponent("staging/model.gguf")
        let store = LocalRewriteBackgroundDownloadJobStore(
            fileManager: .default,
            jobURLProvider: { jobURL }
        )
        let coordinator = LocalRewriteBackgroundDownloadCoordinator(
            fileManager: .default,
            jobStore: store,
            stagingArtifactURLProvider: { stagingURL }
        )
        var job = LocalRewriteBackgroundDownloadJob(descriptor: LocalRewriteModelCatalog.descriptor)
        job.phase = .downloading
        job.completedBytes = 200_000_000
        try store.save(job)
        let descriptor = ResumableDownloadTaskDescriptor(
            jobID: job.id,
            artifactID: job.artifactFilename
        )

        coordinator.updateDownloadProgress(
            for: descriptor,
            taskIdentifier: 42,
            totalBytesWritten: 10_000,
            totalBytesExpectedToWrite: job.expectedByteCount
        )

        #expect(store.load()?.completedBytes == 200_000_000)
    }

    @Test func completedTransportFileMovesIntoExistingVibesStagingLocation() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let jobURL = rootURL.appendingPathComponent("background-download-job.json")
        let stagingURL = rootURL.appendingPathComponent("staging/model.gguf")
        let temporaryURL = rootURL.appendingPathComponent("download.tmp")
        let downloadedData = Data(repeating: 7, count: 32)
        try downloadedData.write(to: temporaryURL)
        let store = LocalRewriteBackgroundDownloadJobStore(
            fileManager: .default,
            jobURLProvider: { jobURL }
        )
        let coordinator = LocalRewriteBackgroundDownloadCoordinator(
            fileManager: .default,
            jobStore: store,
            stagingArtifactURLProvider: { stagingURL }
        )
        let job = LocalRewriteBackgroundDownloadJob(descriptor: LocalRewriteModelCatalog.descriptor)
        try store.save(job)
        let descriptor = ResumableDownloadTaskDescriptor(
            jobID: job.id,
            artifactID: job.artifactFilename
        )

        coordinator.resumableDownloadTransport(
            coordinator.transport,
            didFinishDownloading: descriptor,
            to: temporaryURL,
            response: nil
        )

        #expect(try Data(contentsOf: stagingURL) == downloadedData)
        #expect(store.load()?.phase == .downloaded)
        #expect(store.load()?.finalizationState == .pending)
    }

    @Test func unsuccessfulHTTPResponseDoesNotStageDownloadedFile() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        let jobURL = rootURL.appendingPathComponent("background-download-job.json")
        let stagingURL = rootURL.appendingPathComponent("staging/model.gguf")
        let temporaryURL = rootURL.appendingPathComponent("download.tmp")
        try Data("Not found".utf8).write(to: temporaryURL)
        let store = LocalRewriteBackgroundDownloadJobStore(
            fileManager: .default,
            jobURLProvider: { jobURL }
        )
        let coordinator = LocalRewriteBackgroundDownloadCoordinator(
            fileManager: .default,
            jobStore: store,
            stagingArtifactURLProvider: { stagingURL }
        )
        let job = LocalRewriteBackgroundDownloadJob(descriptor: LocalRewriteModelCatalog.descriptor)
        try store.save(job)
        let descriptor = ResumableDownloadTaskDescriptor(
            jobID: job.id,
            artifactID: job.artifactFilename
        )
        let response = HTTPURLResponse(
            url: job.remoteURL,
            statusCode: 404,
            httpVersion: nil,
            headerFields: nil
        )

        coordinator.resumableDownloadTransport(
            coordinator.transport,
            didFinishDownloading: descriptor,
            to: temporaryURL,
            response: response
        )

        #expect(!FileManager.default.fileExists(atPath: stagingURL.path))
        #expect(store.load()?.phase == .failed)
        #expect(store.load()?.finalizationState == .failed)
    }

    @Test func VibesAndSpeakUseIndependentBackgroundSessionIdentifiers() {
        #expect(
            LocalRewriteBackgroundDownloadCoordinator.sessionIdentifier
                != PocketTTSBackgroundDownloadCoordinator.sessionIdentifier
        )
    }
}
