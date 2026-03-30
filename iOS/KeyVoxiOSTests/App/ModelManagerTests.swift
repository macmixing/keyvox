import CryptoKit
import Foundation
import KeyVoxCore
import Testing
@testable import KeyVox_iOS

@MainActor
struct ModelManagerTests {
    @Test func refreshStatusWithoutFilesReportsAllModelsNotInstalled() {
        let harness = makeHarness()
        defer { harness.cleanup() }

        harness.manager.refreshStatus()

        #expect(harness.manager.state(for: .whisperBase) == .notInstalled)
        #expect(harness.manager.state(for: .parakeetTdtV3) == .notInstalled)
        #expect(harness.manager.installState == .notInstalled)
        #expect(harness.manager.modelReady == false)
    }

    @Test func legacyWhisperMigrationMovesFilesIntoWhisperFolder() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        try harness.writeLegacyWhisperInstall()

        harness.manager.refreshStatus()

        #expect(harness.fileManager.fileExists(atPath: harness.whisperGGMLURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.whisperCoreMLDirectoryURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.whisperManifestURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.legacyWhisperGGMLURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.legacyWhisperCoreMLDirectoryURL.path) == false)
        #expect(harness.fileManager.fileExists(atPath: harness.legacyWhisperManifestURL.path) == false)
        #expect(harness.manager.state(for: .whisperBase) == .ready)
    }

    @Test func refreshStatusTracksWhisperAndParakeetIndependently() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        try harness.writeInstalledModel(.whisperBase)
        try harness.writeInstalledModel(.parakeetTdtV3)

        harness.manager.refreshStatus()

        #expect(harness.manager.state(for: .whisperBase) == .ready)
        #expect(harness.manager.state(for: .parakeetTdtV3) == .ready)
        #expect(harness.manager.installState == .ready)
        #expect(harness.manager.modelReady == true)
    }

    @Test func persistedParakeetBackgroundJobOnlyMarksParakeetInstalling() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        let parakeetDescriptor = harness.descriptorProvider(.parakeetTdtV3)
        let firstArtifact = try #require(parakeetDescriptor.artifacts.first)
        try harness.writeBackgroundJob(
            ModelBackgroundDownloadJob(
                modelID: .parakeetTdtV3,
                artifactStatesByRelativePath: [
                    firstArtifact.relativePath: .init(
                        phase: .downloading,
                        taskIdentifier: 19,
                        completedBytes: 25,
                        expectedBytes: 100
                    )
                ],
                finalizationState: .awaitingDownloads
            )
        )

        harness.manager.refreshStatus()

        guard case .downloading = harness.manager.state(for: .parakeetTdtV3) else {
            Issue.record("Expected Parakeet to report downloading state from the persisted background job.")
            return
        }
        #expect(harness.manager.state(for: .whisperBase) == .notInstalled)
    }

    @Test func successfulWhisperDownloadInstallsIntoWhisperFolderAndWarmsProvider() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }

        await harness.manager.performDownloadModel(withID: .whisperBase)

        #expect(harness.manager.state(for: .whisperBase) == .ready)
        #expect(harness.manager.installState == .ready)
        #expect(harness.whisperLifecycle.unloadCallCount == 1)
        #expect(harness.whisperLifecycle.warmupCallCount == 1)
        #expect(harness.fileManager.fileExists(atPath: harness.whisperGGMLURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.whisperCoreMLDirectoryURL.path))
        #expect(harness.fileManager.fileExists(atPath: harness.whisperManifestURL.path))
    }

    @Test func deleteWhisperRemovesInstalledArtifacts() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        try harness.writeInstalledModel(.whisperBase)

        harness.manager.deleteModel(withID: .whisperBase)

        #expect(harness.manager.state(for: .whisperBase) == .notInstalled)
        #expect(harness.whisperLifecycle.unloadCallCount == 1)
        #expect(harness.fileManager.fileExists(atPath: harness.whisperRootURL.path) == false)
    }

    @Test func deleteParakeetRemovesInstalledArtifacts() throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        try harness.writeInstalledModel(.parakeetTdtV3)

        harness.manager.deleteModel(withID: .parakeetTdtV3)

        #expect(harness.manager.state(for: .parakeetTdtV3) == .notInstalled)
        #expect(harness.parakeetLifecycle.unloadCallCount == 1)
        #expect(harness.fileManager.fileExists(atPath: harness.parakeetRootURL.path) == false)
    }

    @Test func repairingWhisperDoesNotMutateReadyParakeetInstallState() async throws {
        let harness = makeHarness()
        defer { harness.cleanup() }
        try harness.writeInstalledModel(.parakeetTdtV3)
        try harness.writePartialWhisperInstall()

        await harness.manager.performRepairModelIfNeeded(for: .whisperBase)

        #expect(harness.manager.state(for: .whisperBase) == .ready)
        #expect(harness.manager.state(for: .parakeetTdtV3) == .ready)
        #expect(harness.parakeetLifecycle.unloadCallCount == 0)
    }

    private func makeHarness(freeSpace: Int64 = 1_000_000_000) -> ModelManagerHarness {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileManager = FileManager.default
        let modelsDirectoryURL = rootURL.appendingPathComponent("Models", isDirectory: true)
        let locator = InstalledDictationModelLocator(
            fileManager: fileManager,
            modelsDirectoryURL: modelsDirectoryURL
        )
        let descriptorProvider = Self.makeDescriptorProvider(rootURL: rootURL)
        let whisperLifecycle = StubLifecycle()
        let parakeetLifecycle = StubLifecycle()
        let backgroundJobURL = modelsDirectoryURL.appendingPathComponent("model-download-job.json")
        let backgroundJobStore = ModelBackgroundDownloadJobStore(
            fileManager: fileManager,
            jobURLProvider: { backgroundJobURL }
        )
        let manager = ModelManager(
            fileManager: fileManager,
            modelLocator: locator,
            backgroundJobStore: backgroundJobStore,
            lifecycleProvider: { modelID in
                switch modelID {
                case .whisperBase:
                    return whisperLifecycle
                case .parakeetTdtV3:
                    return parakeetLifecycle
                }
            },
            descriptorProvider: descriptorProvider,
            freeSpaceProvider: { _ in freeSpace },
            download: { url, progress in
                progress(.complete)
                return try Self.fixtureURL(for: url, rootURL: rootURL)
            },
            unzip: Self.makeUnzipStub()
        )

        return ModelManagerHarness(
            manager: manager,
            fileManager: fileManager,
            rootURL: rootURL,
            locator: locator,
            backgroundJobURL: backgroundJobURL,
            descriptorProvider: descriptorProvider,
            whisperLifecycle: whisperLifecycle,
            parakeetLifecycle: parakeetLifecycle
        )
    }

    nonisolated private static func makeDescriptorProvider(
        rootURL: URL
    ) -> (DictationModelID) -> DictationModelDescriptor {
        let whisperGGMLFixtureURL = makeTempFile(in: rootURL, prefix: "whisper-ggml", data: Data(repeating: 0x5A, count: 2_048))
        let whisperCoreMLFixtureURL = makeTempFile(in: rootURL, prefix: "whisper-coreml", data: Data(repeating: 0x6B, count: 1_024))
        let parakeetConfigFixtureURL = makeTempFile(in: rootURL, prefix: "parakeet-config", data: Data("{}".utf8))
        let parakeetWeightsFixtureURL = makeTempFile(in: rootURL, prefix: "parakeet-weights", data: Data(repeating: 0x4D, count: 512))

        let whisperDescriptor = DictationModelDescriptor(
            id: .whisperBase,
            displayName: "Whisper Base",
            installLayout: .subdirectory("whisper"),
            artifacts: [
                DictationModelArtifact(
                    relativePath: "ggml-base.bin",
                    remoteURL: URL(string: "https://example.com/test-whisper-ggml.bin")!,
                    expectedSHA256: sha256Hex(forFileAt: whisperGGMLFixtureURL),
                    progressTotalBytes: 2_048,
                    retainedAfterInstall: true
                ),
                DictationModelArtifact(
                    relativePath: "ggml-base-encoder.mlmodelc.zip",
                    remoteURL: URL(string: "https://example.com/test-whisper-coreml.zip")!,
                    expectedSHA256: sha256Hex(forFileAt: whisperCoreMLFixtureURL),
                    progressTotalBytes: 1_024,
                    retainedAfterInstall: false
                )
            ],
            requiredDownloadBytes: 4_096
        )

        let parakeetDescriptor = DictationModelDescriptor(
            id: .parakeetTdtV3,
            displayName: "Parakeet TDT v3",
            installLayout: .subdirectory("parakeet"),
            artifacts: [
                DictationModelArtifact(
                    relativePath: "config.json",
                    remoteURL: URL(string: "https://example.com/test-parakeet-config.json")!,
                    expectedSHA256: sha256Hex(forFileAt: parakeetConfigFixtureURL),
                    progressTotalBytes: 64,
                    retainedAfterInstall: true
                ),
                DictationModelArtifact(
                    relativePath: "Encoder.mlmodelc/weights/weight.bin",
                    remoteURL: URL(string: "https://example.com/test-parakeet-weight.bin")!,
                    expectedSHA256: sha256Hex(forFileAt: parakeetWeightsFixtureURL),
                    progressTotalBytes: 512,
                    retainedAfterInstall: true
                )
            ],
            requiredDownloadBytes: 1_024
        )

        return { modelID in
            switch modelID {
            case .whisperBase:
                whisperDescriptor
            case .parakeetTdtV3:
                parakeetDescriptor
            }
        }
    }

    nonisolated private static func fixtureURL(for url: URL, rootURL: URL) throws -> URL {
        switch url.absoluteString {
        case "https://example.com/test-whisper-ggml.bin":
            return rootURL.appendingPathComponent("whisper-ggml")
        case "https://example.com/test-whisper-coreml.zip":
            return rootURL.appendingPathComponent("whisper-coreml")
        case "https://example.com/test-parakeet-config.json":
            return rootURL.appendingPathComponent("parakeet-config")
        case "https://example.com/test-parakeet-weight.bin":
            return rootURL.appendingPathComponent("parakeet-weights")
        default:
            throw CocoaError(.fileNoSuchFile)
        }
    }

    nonisolated private static func makeTempFile(in directoryURL: URL, prefix: String, data: Data) -> URL {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let url = directoryURL.appendingPathComponent(prefix)
        try? data.write(to: url)
        return url
    }

    nonisolated private static func sha256Hex(forFileAt url: URL) -> String {
        let data = (try? Data(contentsOf: url)) ?? Data()
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    nonisolated private static func makeUnzipStub() -> ModelManager.UnzipClosure {
        { _, destinationDirectory, fileManager, progress in
            progress(0, 1)
            let coreMLDirectoryURL = destinationDirectory.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
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
    let fileManager: FileManager
    let rootURL: URL
    let locator: InstalledDictationModelLocator
    let backgroundJobURL: URL
    let descriptorProvider: (DictationModelID) -> DictationModelDescriptor
    let whisperLifecycle: StubLifecycle
    let parakeetLifecycle: StubLifecycle

    init(
        manager: ModelManager,
        fileManager: FileManager,
        rootURL: URL,
        locator: InstalledDictationModelLocator,
        backgroundJobURL: URL,
        descriptorProvider: @escaping (DictationModelID) -> DictationModelDescriptor,
        whisperLifecycle: StubLifecycle,
        parakeetLifecycle: StubLifecycle
    ) {
        self.manager = manager
        self.fileManager = fileManager
        self.rootURL = rootURL
        self.locator = locator
        self.backgroundJobURL = backgroundJobURL
        self.descriptorProvider = descriptorProvider
        self.whisperLifecycle = whisperLifecycle
        self.parakeetLifecycle = parakeetLifecycle
    }

    var whisperRootURL: URL { locator.installRootURL(for: .whisperBase)! }
    var whisperGGMLURL: URL { locator.artifactURL(for: .whisperBase, relativePath: "ggml-base.bin")! }
    var whisperCoreMLDirectoryURL: URL { locator.artifactURL(for: .whisperBase, relativePath: "ggml-base-encoder.mlmodelc")! }
    var whisperManifestURL: URL { locator.manifestURL(for: .whisperBase)! }
    var parakeetRootURL: URL { locator.installRootURL(for: .parakeetTdtV3)! }
    var legacyWhisperGGMLURL: URL { locator.modelsDirectoryURL!.appendingPathComponent("ggml-base.bin") }
    var legacyWhisperCoreMLDirectoryURL: URL { locator.modelsDirectoryURL!.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true) }
    var legacyWhisperManifestURL: URL { locator.modelsDirectoryURL!.appendingPathComponent("model-install-manifest.json") }

    func cleanup() {
        try? fileManager.removeItem(at: rootURL)
    }

    func writeInstalledModel(_ modelID: DictationModelID) throws {
        let descriptor = descriptorProvider(modelID)
        guard let installRootURL = locator.installRootURL(for: modelID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try fileManager.createDirectory(at: installRootURL, withIntermediateDirectories: true)

        for artifact in descriptor.artifacts {
            guard let artifactURL = locator.artifactURL(for: modelID, relativePath: artifact.relativePath) else {
                throw CocoaError(.fileNoSuchFile)
            }
            let parentDirectory = artifactURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectory.path) {
                try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }
            try Data("installed".utf8).write(to: artifactURL)
        }

        if modelID == .whisperBase {
            try fileManager.createDirectory(at: whisperCoreMLDirectoryURL, withIntermediateDirectories: true)
            try Data("coreml".utf8).write(to: whisperCoreMLDirectoryURL.appendingPathComponent("Manifest.plist"))
            guard let zipURL = locator.artifactURL(for: .whisperBase, relativePath: "ggml-base-encoder.mlmodelc.zip") else {
                throw CocoaError(.fileNoSuchFile)
            }
            try? fileManager.removeItem(at: zipURL)
        }

        let manifest = DictationModelInstallManifest(
            artifactSHA256ByRelativePath: Dictionary(
                uniqueKeysWithValues: descriptor.artifacts.map { ($0.relativePath, $0.expectedSHA256) }
            )
        )
        let manifestData = try JSONEncoder().encode(manifest)
        guard let manifestURL = locator.manifestURL(for: modelID) else {
            throw CocoaError(.fileNoSuchFile)
        }
        try manifestData.write(to: manifestURL)
    }

    func writePartialWhisperInstall() throws {
        try fileManager.createDirectory(at: whisperRootURL, withIntermediateDirectories: true)
        try Data("partial".utf8).write(to: whisperGGMLURL)
    }

    func writeLegacyWhisperInstall() throws {
        try fileManager.createDirectory(at: locator.modelsDirectoryURL!, withIntermediateDirectories: true)
        try Data("legacy-whisper".utf8).write(to: legacyWhisperGGMLURL)
        try fileManager.createDirectory(at: legacyWhisperCoreMLDirectoryURL, withIntermediateDirectories: true)
        try Data("coreml".utf8).write(to: legacyWhisperCoreMLDirectoryURL.appendingPathComponent("Manifest.plist"))

        let descriptor = descriptorProvider(.whisperBase)
        let manifest = DictationModelInstallManifest(
            artifactSHA256ByRelativePath: Dictionary(
                uniqueKeysWithValues: descriptor.artifacts.map { ($0.relativePath, $0.expectedSHA256) }
            )
        )
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: legacyWhisperManifestURL)
    }

    func writeBackgroundJob(_ job: ModelBackgroundDownloadJob) throws {
        try fileManager.createDirectory(at: locator.modelsDirectoryURL!, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(job)
        try data.write(to: backgroundJobURL)
    }
}

@MainActor
private final class StubLifecycle: DictationModelLifecycleProviding {
    private(set) var warmupCallCount = 0
    private(set) var unloadCallCount = 0

    func warmup() {
        warmupCallCount += 1
    }

    func unloadModel() {
        unloadCallCount += 1
    }
}
