import CryptoKit
import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSModelManagerTests {
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

    private func makeHarness(freeSpace: Int64 = 300_000_000) -> ModelManagerHarness {
        let rootURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileManager = FileManager.default
        let modelsDirectoryURL = rootURL.appendingPathComponent("Models", isDirectory: true)
        let ggmlModelURL = modelsDirectoryURL.appendingPathComponent("ggml-base.bin")
        let coreMLZipURL = modelsDirectoryURL.appendingPathComponent("ggml-base-encoder.mlmodelc.zip")
        let coreMLDirectoryURL = modelsDirectoryURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
        let manifestURL = modelsDirectoryURL.appendingPathComponent("model-install-manifest.json")
        let whisperService = StubWhisperLifecycle()

        let fixturesDirectoryURL = rootURL.appendingPathComponent("Fixtures", isDirectory: true)
        let ggmlFixtureURL = Self.makeTempFile(in: fixturesDirectoryURL, prefix: "ggml", size: 2_048)
        let coreMLZipFixtureURL = Self.makeTempFile(in: fixturesDirectoryURL, prefix: "coreml", size: 1_024)
        let manager = iOSModelManager(
            fileManager: fileManager,
            whisperService: whisperService,
            modelsDirectoryProvider: { modelsDirectoryURL },
            ggmlModelURLProvider: { ggmlModelURL },
            coreMLZipURLProvider: { coreMLZipURL },
            coreMLDirectoryURLProvider: { coreMLDirectoryURL },
            manifestURLProvider: { manifestURL },
            minGGMLBytes: 1_024,
            expectedGGMLSHA256: Self.sha256Hex(forFileAt: ggmlFixtureURL),
            expectedCoreMLZipSHA256: Self.sha256Hex(forFileAt: coreMLZipFixtureURL),
            freeSpaceProvider: { _ in freeSpace },
            download: { url, progress in
                progress(.complete)
                if url == iOSModelDownloadURLs.ggmlBase {
                    return ggmlFixtureURL
                }
                return coreMLZipFixtureURL
            },
            unzip: { _, _, fileManager, progress in
                progress(0, 1)
                if !fileManager.fileExists(atPath: coreMLDirectoryURL.path) {
                    try fileManager.createDirectory(at: coreMLDirectoryURL, withIntermediateDirectories: true)
                }
                try Data("coreml".utf8).write(to: coreMLDirectoryURL.appendingPathComponent("Manifest.plist"))
                progress(1, 1)
            }
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

}

@MainActor
private final class ModelManagerHarness {
    let manager: iOSModelManager
    let whisperService: StubWhisperLifecycle
    let fileManager: FileManager
    let rootURL: URL
    let modelsDirectoryURL: URL
    let ggmlModelURL: URL
    let coreMLZipURL: URL
    let coreMLDirectoryURL: URL
    let manifestURL: URL
    let expectedGGMLSHA256: String
    let expectedCoreMLZipSHA256: String

    init(
        manager: iOSModelManager,
        whisperService: StubWhisperLifecycle,
        fileManager: FileManager,
        rootURL: URL,
        modelsDirectoryURL: URL,
        ggmlModelURL: URL,
        coreMLZipURL: URL,
        coreMLDirectoryURL: URL,
        manifestURL: URL,
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
        let manifest = iOSModelInstallManifest(
            version: iOSModelInstallManifest.currentVersion,
            ggmlSHA256: expectedGGMLSHA256,
            coreMLZipSHA256: expectedCoreMLZipSHA256
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL)
    }
}

@MainActor
private final class StubWhisperLifecycle: iOSWhisperModelLifecycle {
    private(set) var warmupCallCount = 0
    private(set) var unloadCallCount = 0

    func warmup() {
        warmupCallCount += 1
    }

    func unloadModel() {
        unloadCallCount += 1
    }
}
