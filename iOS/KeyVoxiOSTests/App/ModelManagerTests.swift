import CryptoKit
import Foundation
import KeyVoxCore
import Testing
@testable import KeyVox_iOS

@MainActor
struct ModelManagerTests {
    @Test func refreshStatusWithoutFilesReportsNotInstalled() {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.refreshStatus()

        #expect(harness.manager.installState == .notInstalled)
        #expect(harness.manager.modelReady == false)
        #expect(harness.manager.errorMessage == nil)
    }

    @Test func refreshStatusWithCompleteInstallReportsReady() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        try harness.writeGGMLFile()
        try harness.writeCoreMLDirectory()
        try harness.writeValidManifest()

        harness.manager.refreshStatus()

        #expect(harness.manager.installState == .ready)
        #expect(harness.manager.modelReady == true)
    }

    @Test func refreshStatusWithOnlyGGMLReportsIncompleteInstall() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        try harness.writeGGMLFile()

        harness.manager.refreshStatus()

        #expect(harness.manager.modelReady == false)
        guard case .failed(let message) = harness.manager.installState else {
            Issue.record("Expected failed install state for incomplete model install.")
            return
        }
        #expect(message.contains("ggml-base-encoder.mlmodelc"))
    }

    @Test func refreshStatusWithPersistedBackgroundDownloadReportsDownloading() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        try harness.writeBackgroundJob(
            ModelBackgroundDownloadJob(
                ggml: .init(
                    phase: .downloading,
                    taskIdentifier: 11,
                    completedBytes: 25,
                    expectedBytes: 100
                ),
                coreMLZip: .init(
                    phase: .pending
                ),
                finalizationState: .awaitingDownloads
            )
        )

        harness.manager.refreshStatus()

        guard case .downloading(_, let phase) = harness.manager.installState else {
            Issue.record("Expected downloading install state for persisted background download job.")
            return
        }
        #expect(phase == .downloadingAssets)
        #expect(harness.manager.modelReady == false)
        #expect(harness.manager.errorMessage == nil)
    }

    @Test func refreshStatusWithPendingFinalizationReportsInstalling() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        try harness.writeBackgroundJob(
            ModelBackgroundDownloadJob(
                ggml: .init(
                    phase: .downloaded,
                    completedBytes: 2_048,
                    expectedBytes: 2_048
                ),
                coreMLZip: .init(
                    phase: .downloaded,
                    completedBytes: 1_024,
                    expectedBytes: 1_024
                ),
                finalizationState: .pending
            )
        )

        harness.manager.refreshStatus()

        guard case .installing(_, let phase) = harness.manager.installState else {
            Issue.record("Expected installing state when both background artifacts are downloaded.")
            return
        }
        #expect(phase == .resumingInstall)
        #expect(harness.manager.modelReady == false)
        #expect(harness.manager.errorMessage == nil)
    }

    @Test func refreshStatusWithFailedBackgroundJobReportsFailure() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        try harness.writeBackgroundJob(
            ModelBackgroundDownloadJob(
                finalizationState: .failed,
                lastErrorMessage: "Network died"
            )
        )

        harness.manager.refreshStatus()

        guard case .failed(let message) = harness.manager.installState else {
            Issue.record("Expected failed install state for persisted background job failure.")
            return
        }
        #expect(message == "Network died")
        #expect(harness.manager.errorMessage == "Network died")
        #expect(harness.manager.modelReady == false)
    }

    @Test func successfulDownloadInstallsModelAndWarmsWhisper() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performDownloadModel()

        #expect(harness.manager.installState == .ready)
        #expect(harness.manager.modelReady == true)
        #expect(harness.whisperService.unloadCallCount == 1)
        #expect(harness.whisperService.warmupCallCount == 1)
        #expect(harness.fileManager.fileExists(atPath: harness.ggmlModelURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.coreMLDirectoryURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.coreMLZipURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.manifestURL.path))
    }

    @Test func foregroundFinalizationCompletesDownloadedBackgroundJob() async throws {
        let harness = makeHarness(includeBackgroundCoordinator: true)
        defer { harness.cleanup() }

        try harness.writeStagedGGMLFixture()
        try harness.writeStagedCoreMLZipFixture()
        try harness.writeBackgroundJob(
            ModelBackgroundDownloadJob(
                ggml: .init(
                    phase: .downloaded,
                    completedBytes: 2_048,
                    expectedBytes: 2_048
                ),
                coreMLZip: .init(
                    phase: .downloaded,
                    completedBytes: 1_024,
                    expectedBytes: 1_024
                ),
                finalizationState: .pending
            )
        )

        harness.manager.appIsActive = true
        await harness.manager.resumeForegroundFinalizationIfNeeded()

        #expect(harness.manager.installState == .ready)
        #expect(harness.manager.modelReady == true)
        #expect(harness.whisperService.unloadCallCount == 1)
        #expect(harness.whisperService.warmupCallCount == 1)
        #expect(harness.fileManager.fileExists(atPath: harness.ggmlModelURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.coreMLDirectoryURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.coreMLZipURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.backgroundJobURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.stagedGGMLURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.stagedCoreMLZipURL.path) == false)
    }

    @Test func deleteRemovesInstalledArtifactsAndUnloadsWhisper() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        try harness.writeGGMLFile()
        try harness.writeCoreMLDirectory()
        try harness.writeValidManifest()

        harness.manager.deleteModel()

        #expect(harness.manager.installState == .notInstalled)
        #expect(harness.whisperService.unloadCallCount == 1)
        #expect(harness.fileManager.fileExists(atPath: harness.ggmlModelURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.coreMLDirectoryURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.manifestURL.path) == false)
    }

    @Test func deleteRemovesPersistedBackgroundArtifacts() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        try harness.writeBackgroundJob(ModelBackgroundDownloadJob())
        try harness.writeStagedGGMLFixture()
        try harness.writeStagedCoreMLZipFixture()

        harness.manager.deleteModel()

        #expect(harness.fileManager.fileExists(atPath: harness.backgroundJobURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.stagedGGMLURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.stagedCoreMLZipURL.path) == false)
    }

    @Test func repairRemovesPartialInstallAndRedownloadsModel() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        try harness.writeGGMLFile()
        try harness.writeCoreMLZipFile()

        await harness.manager.performRepairModelIfNeeded()

        #expect(harness.manager.installState == .ready)
        #expect(harness.whisperService.unloadCallCount == 1)
        #expect(harness.whisperService.warmupCallCount == 1)
        #expect(harness.fileManager.fileExists(atPath: harness.coreMLDirectoryURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.coreMLZipURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.manifestURL.path))
    }

    @Test func lowDiskSpaceFailsWithoutStartingInstall() async {
        let harness = makeHarness(freeSpace: 1_000)
        defer { harness.cleanup() }

        await harness.manager.performDownloadModel()

        #expect(harness.manager.modelReady == false)
        guard case .failed(let message) = harness.manager.installState else {
            Issue.record("Expected failed install state for low disk space.")
            return
        }
        #expect(message.contains("Not enough free disk space"))
        #expect(harness.whisperService.warmupCallCount == 0)
    }

    private func makeHarness(
        freeSpace: Int64 = 300_000_000,
        includeBackgroundCoordinator: Bool = false
    ) -> ModelManagerHarness {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileManager = FileManager.default
        let modelsDirectoryURL = rootURL.appendingPathComponent("Models", isDirectory: true)
        let stagingDirectoryURL = modelsDirectoryURL.appendingPathComponent("DownloadStaging", isDirectory: true)
        let ggmlModelURL = modelsDirectoryURL.appendingPathComponent("ggml-base.bin")
        let coreMLZipURL = modelsDirectoryURL.appendingPathComponent("ggml-base-encoder.mlmodelc.zip")
        let coreMLDirectoryURL = modelsDirectoryURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
        let manifestURL = modelsDirectoryURL.appendingPathComponent("model-install-manifest.json")
        let backgroundJobURL = modelsDirectoryURL.appendingPathComponent("model-download-job.json")
        let stagedGGMLURL = stagingDirectoryURL.appendingPathComponent("ggml-base.bin")
        let stagedCoreMLZipURL = stagingDirectoryURL.appendingPathComponent("ggml-base-encoder.mlmodelc.zip")
        let whisperService = StubWhisperLifecycle()

        let fixturesDirectoryURL = rootURL.appendingPathComponent("Fixtures", isDirectory: true)
        let ggmlFixtureURL = Self.makeTempFile(in: fixturesDirectoryURL, prefix: "ggml", size: 2_048)
        let coreMLZipFixtureURL = Self.makeTempFile(in: fixturesDirectoryURL, prefix: "coreml", size: 1_024)
        let backgroundDownloadCoordinator = includeBackgroundCoordinator
            ? ModelBackgroundDownloadCoordinator(
                fileManager: fileManager,
                jobStore: ModelBackgroundDownloadJobStore(
                    fileManager: fileManager,
                    jobURLProvider: { backgroundJobURL }
                ),
                modelsDirectoryURLProvider: { modelsDirectoryURL },
                stagedGGMLURLProvider: { stagedGGMLURL },
                stagedCoreMLZipURLProvider: { stagedCoreMLZipURL }
            )
            : nil
        let manager = ModelManager(
            fileManager: fileManager,
            providerLifecycle: whisperService,
            modelsDirectoryProvider: { modelsDirectoryURL },
            ggmlModelURLProvider: { ggmlModelURL },
            coreMLZipURLProvider: { coreMLZipURL },
            coreMLDirectoryURLProvider: { coreMLDirectoryURL },
            manifestURLProvider: { manifestURL },
            modelDownloadJobURLProvider: { backgroundJobURL },
            stagedGGMLURLProvider: { stagedGGMLURL },
            stagedCoreMLZipURLProvider: { stagedCoreMLZipURL },
            minGGMLBytes: 1_024,
            expectedGGMLSHA256: Self.sha256Hex(forFileAt: ggmlFixtureURL),
            expectedCoreMLZipSHA256: Self.sha256Hex(forFileAt: coreMLZipFixtureURL),
            freeSpaceProvider: { _ in freeSpace },
            backgroundDownloadCoordinator: backgroundDownloadCoordinator,
            download: { url, progress in
                progress(.complete)
                if url == ModelDownloadURLs.ggmlBase {
                    return ggmlFixtureURL
                }
                return coreMLZipFixtureURL
            },
            unzip: Self.makeUnzipStub(coreMLDirectoryURL: coreMLDirectoryURL)
        )

        return ModelManagerHarness(
            manager: manager,
            whisperService: whisperService,
            fileManager: fileManager,
            rootURL: rootURL,
            modelsDirectoryURL: modelsDirectoryURL,
            ggmlModelURL: ggmlModelURL,
            coreMLZipURL: coreMLZipURL,
            coreMLDirectoryURL: coreMLDirectoryURL,
            manifestURL: manifestURL,
            backgroundJobURL: backgroundJobURL,
            stagedGGMLURL: stagedGGMLURL,
            stagedCoreMLZipURL: stagedCoreMLZipURL,
            ggmlFixtureURL: ggmlFixtureURL,
            coreMLZipFixtureURL: coreMLZipFixtureURL,
            expectedGGMLSHA256: Self.sha256Hex(forFileAt: ggmlFixtureURL),
            expectedCoreMLZipSHA256: Self.sha256Hex(forFileAt: coreMLZipFixtureURL)
        )
    }

    nonisolated private static func makeTempFile(in directoryURL: URL, prefix: String, size: Int) -> URL {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let url = directoryURL
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
        let data = Data(repeating: 0x5A, count: size)
        try? data.write(to: url)
        return url
    }

    nonisolated private static func sha256Hex(forFileAt url: URL) -> String {
        let data = (try? Data(contentsOf: url)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func makeUnzipStub(coreMLDirectoryURL: URL) -> ModelManager.UnzipClosure {
        { _, _, fileManager, progress in
            progress(0, 1)
            if !fileManager.fileExists(atPath: coreMLDirectoryURL.path) {
                try fileManager.createDirectory(at: coreMLDirectoryURL, withIntermediateDirectories: true)
            }
            try Data("coreml".utf8).write(to: coreMLDirectoryURL.appendingPathComponent("Manifest.plist"))
            progress(1, 1)
        }
    }

}

@MainActor
private final class ModelManagerHarness {
    let manager: ModelManager
    let whisperService: StubWhisperLifecycle
    let fileManager: FileManager
    let rootURL: URL
    let modelsDirectoryURL: URL
    let ggmlModelURL: URL
    let coreMLZipURL: URL
    let coreMLDirectoryURL: URL
    let manifestURL: URL
    let backgroundJobURL: URL
    let stagedGGMLURL: URL
    let stagedCoreMLZipURL: URL
    let ggmlFixtureURL: URL
    let coreMLZipFixtureURL: URL
    let expectedGGMLSHA256: String
    let expectedCoreMLZipSHA256: String

    init(
        manager: ModelManager,
        whisperService: StubWhisperLifecycle,
        fileManager: FileManager,
        rootURL: URL,
        modelsDirectoryURL: URL,
        ggmlModelURL: URL,
        coreMLZipURL: URL,
        coreMLDirectoryURL: URL,
        manifestURL: URL,
        backgroundJobURL: URL,
        stagedGGMLURL: URL,
        stagedCoreMLZipURL: URL,
        ggmlFixtureURL: URL,
        coreMLZipFixtureURL: URL,
        expectedGGMLSHA256: String,
        expectedCoreMLZipSHA256: String
    ) {
        self.manager = manager
        self.whisperService = whisperService
        self.fileManager = fileManager
        self.rootURL = rootURL
        self.modelsDirectoryURL = modelsDirectoryURL
        self.ggmlModelURL = ggmlModelURL
        self.coreMLZipURL = coreMLZipURL
        self.coreMLDirectoryURL = coreMLDirectoryURL
        self.manifestURL = manifestURL
        self.backgroundJobURL = backgroundJobURL
        self.stagedGGMLURL = stagedGGMLURL
        self.stagedCoreMLZipURL = stagedCoreMLZipURL
        self.ggmlFixtureURL = ggmlFixtureURL
        self.coreMLZipFixtureURL = coreMLZipFixtureURL
        self.expectedGGMLSHA256 = expectedGGMLSHA256
        self.expectedCoreMLZipSHA256 = expectedCoreMLZipSHA256
    }

    func cleanup() {
        try? fileManager.removeItem(at: rootURL)
    }

    func writeGGMLFile(size: Int = 2_048) throws {
        if !fileManager.fileExists(atPath: modelsDirectoryURL.path) {
            try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
        }
        try Data(repeating: 0x5A, count: size).write(to: ggmlModelURL)
    }

    func writeCoreMLDirectory() throws {
        if !fileManager.fileExists(atPath: coreMLDirectoryURL.path) {
            try fileManager.createDirectory(at: coreMLDirectoryURL, withIntermediateDirectories: true)
        }
        try Data("coreml".utf8).write(to: coreMLDirectoryURL.appendingPathComponent("Manifest.plist"))
    }

    func writeCoreMLZipFile() throws {
        if !fileManager.fileExists(atPath: modelsDirectoryURL.path) {
            try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
        }
        try Data("zip".utf8).write(to: coreMLZipURL)
    }

    func writeValidManifest() throws {
        if !fileManager.fileExists(atPath: modelsDirectoryURL.path) {
            try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
        }
        let manifest = ModelInstallManifest(
            version: ModelInstallManifest.currentVersion,
            ggmlSHA256: expectedGGMLSHA256,
            coreMLZipSHA256: expectedCoreMLZipSHA256
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL)
    }

    func writeBackgroundJob(_ job: ModelBackgroundDownloadJob) throws {
        if !fileManager.fileExists(atPath: modelsDirectoryURL.path) {
            try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
        }
        let data = try JSONEncoder().encode(job)
        try data.write(to: backgroundJobURL)
    }

    func writeStagedGGMLFixture() throws {
        let directoryURL = stagedGGMLURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        if fileManager.fileExists(atPath: stagedGGMLURL.path) {
            try fileManager.removeItem(at: stagedGGMLURL)
        }
        try fileManager.copyItem(at: ggmlFixtureURL, to: stagedGGMLURL)
    }

    func writeStagedCoreMLZipFixture() throws {
        let directoryURL = stagedCoreMLZipURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        }
        if fileManager.fileExists(atPath: stagedCoreMLZipURL.path) {
            try fileManager.removeItem(at: stagedCoreMLZipURL)
        }
        try fileManager.copyItem(at: coreMLZipFixtureURL, to: stagedCoreMLZipURL)
    }
}

@MainActor
private final class StubWhisperLifecycle: DictationModelLifecycleProviding {
    private(set) var warmupCallCount = 0
    private(set) var unloadCallCount = 0

    func warmup() {
        warmupCallCount += 1
    }

    func unloadModel() {
        unloadCallCount += 1
    }
}
