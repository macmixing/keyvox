import Foundation
import Testing
@testable import KeyVox_iOS

struct ModelBackgroundDownloadJobTests {
    @Test func jobIdentityRoundTripsThroughPersistentStore() throws {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }
        let store = ModelBackgroundDownloadJobStore(
            fileManager: .default,
            jobURLProvider: { rootURL.appendingPathComponent("model-download-job.json") }
        )
        let job = ModelBackgroundDownloadJob(modelID: .parakeetTdtV3)

        try store.save(job)

        #expect(store.load()?.id == job.id)
        #expect(store.load()?.modelID == job.modelID)
    }

    @Test func multiArtifactProgressDoesNotRegressWhenExpectedBytesGrowDuringHandoff() throws {
        let descriptor = DictationModelCatalog.descriptor(for: .parakeetTdtV3)
        let firstArtifact = try #require(descriptor.artifacts.first)
        let secondArtifact = try #require(descriptor.artifacts.dropFirst().first)
        var job = ModelBackgroundDownloadJob(modelID: .parakeetTdtV3)

        job.setArtifactState(
            .init(
                phase: .downloading,
                completedBytes: firstArtifact.progressTotalBytes,
                expectedBytes: firstArtifact.progressTotalBytes
            ),
            for: firstArtifact.relativePath
        )
        job.setArtifactState(
            .init(
                phase: .downloading,
                completedBytes: secondArtifact.progressTotalBytes / 2,
                expectedBytes: secondArtifact.progressTotalBytes
            ),
            for: secondArtifact.relativePath
        )
        let progressBeforeHandoff = job.downloadProgressFraction

        job.setArtifactState(
            .init(
                phase: .downloading,
                completedBytes: secondArtifact.progressTotalBytes / 4,
                expectedBytes: secondArtifact.progressTotalBytes * 2
            ),
            for: secondArtifact.relativePath
        )

        #expect(job.downloadProgressFraction >= progressBeforeHandoff)
    }
}
