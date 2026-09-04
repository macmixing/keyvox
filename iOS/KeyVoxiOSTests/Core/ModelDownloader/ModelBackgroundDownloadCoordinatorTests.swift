import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
@Suite(.serialized)
struct ModelBackgroundDownloadCoordinatorTests {
    @Test func dictationUsesIndependentBackgroundSessionNamespace() {
        #expect(
            ModelBackgroundDownloadCoordinator.sessionIdentifier
                != PocketTTSBackgroundDownloadCoordinator.sessionIdentifier
        )
        #expect(
            ModelBackgroundDownloadCoordinator.sessionIdentifier
                != LocalRewriteBackgroundDownloadCoordinator.sessionIdentifier
        )
    }

    @Test func lifecycleEntryPointsSettleTransportInRequestedSessionMode() async {
        let harness = makeHarness()
        defer { harness.cleanup() }

        await harness.coordinator.handleAppDidBecomeActive()

        #expect(harness.coordinator.transport.appIsActive)
        #expect(!harness.coordinator.transport.isTransitioning)

        harness.coordinator.handleAppWillResignActive()
        await waitForLifecycleTransition(in: harness.coordinator.transport)

        #expect(!harness.coordinator.transport.appIsActive)
        #expect(!harness.coordinator.transport.isTransitioning)
    }

    @Test func synchronizationRecoversPersistedArtifactFromTransportTask() async throws {
        URLProtocol.registerClass(BlockingDownloadURLProtocol.self)
        defer { URLProtocol.unregisterClass(BlockingDownloadURLProtocol.self) }
        let harness = makeHarness()
        defer { harness.cleanup() }
        let modelID = DictationModelID.parakeetTdtV3
        let artifact = try #require(DictationModelCatalog.descriptor(for: modelID).artifacts.first)
        var job = ModelBackgroundDownloadJob(modelID: modelID)
        job.setArtifactState(
            .init(phase: .downloading, completedBytes: 123, expectedBytes: artifact.progressTotalBytes),
            for: artifact.relativePath
        )
        try harness.store.save(job)
        let task = harness.coordinator.transport.session(for: .foreground).downloadTask(with: artifact.remoteURL)
        task.taskDescription = ResumableDownloadTaskDescriptor(
            jobID: job.id,
            artifactID: artifact.relativePath
        ).encoded
        task.resume()
        await waitForTask(task, in: harness.coordinator.transport)

        let recoveredJob = await harness.coordinator.synchronizeWithSystemTasks()

        #expect(recoveredJob?.artifactState(for: artifact.relativePath).phase == .downloading)
        #expect(recoveredJob?.artifactState(for: artifact.relativePath).taskIdentifier == task.taskIdentifier)
        #expect(recoveredJob?.artifactState(for: artifact.relativePath).completedBytes == 123)
        task.cancel()
    }

    @Test func cancelJobCancelsEveryArtifactTaskInDictationNamespace() async throws {
        URLProtocol.registerClass(BlockingDownloadURLProtocol.self)
        defer { URLProtocol.unregisterClass(BlockingDownloadURLProtocol.self) }
        let harness = makeHarness()
        defer { harness.cleanup() }
        let job = ModelBackgroundDownloadJob(modelID: .whisperBase)
        try harness.store.save(job)
        let artifact = try #require(DictationModelCatalog.descriptor(for: job.modelID).artifacts.first)
        let task = harness.coordinator.transport.session(for: .foreground).downloadTask(with: artifact.remoteURL)
        task.taskDescription = ResumableDownloadTaskDescriptor(
            jobID: job.id,
            artifactID: artifact.relativePath
        ).encoded
        task.resume()
        await waitForTask(task, in: harness.coordinator.transport)

        await harness.coordinator.cancelJob(for: job.modelID)

        #expect(task.state == .canceling || task.state == .completed)
    }

    private func makeHarness() -> CoordinatorHarness {
        let rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let modelsURL = rootURL.appendingPathComponent("Models", isDirectory: true)
        let store = ModelBackgroundDownloadJobStore(
            fileManager: .default,
            jobURLProvider: { modelsURL.appendingPathComponent("model-download-job.json") }
        )
        let locator = InstalledDictationModelLocator(
            fileManager: .default,
            modelsDirectoryURL: modelsURL
        )
        let coordinator = ModelBackgroundDownloadCoordinator(
            fileManager: .default,
            jobStore: store,
            modelLocator: locator
        )
        return CoordinatorHarness(rootURL: rootURL, store: store, coordinator: coordinator)
    }

    private func waitForLifecycleTransition(in transport: ResumableDownloadTransport) async {
        for _ in 0 ..< 1_000 where transport.isTransitioning {
            await Task.yield()
        }
    }

    private func waitForTask(
        _ task: URLSessionDownloadTask,
        in transport: ResumableDownloadTransport
    ) async {
        for _ in 0 ..< 1_000 {
            let tasks = await transport.downloadTasks(in: .foreground)
            if tasks.contains(where: { $0.taskIdentifier == task.taskIdentifier }) {
                return
            }
            await Task.yield()
        }
    }
}

private struct CoordinatorHarness {
    let rootURL: URL
    let store: ModelBackgroundDownloadJobStore
    let coordinator: ModelBackgroundDownloadCoordinator

    func cleanup() {
        coordinator.transport.cancelAllTasksWithoutWaiting()
        try? FileManager.default.removeItem(at: rootURL)
    }
}

private final class BlockingDownloadURLProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {}

    override func stopLoading() {}
}
