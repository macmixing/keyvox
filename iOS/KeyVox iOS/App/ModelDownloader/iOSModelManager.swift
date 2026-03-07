import Combine
import Foundation
import KeyVoxCore

@MainActor
protocol iOSWhisperModelLifecycle: AnyObject {
    func warmup()
    func unloadModel()
}

extension WhisperService: iOSWhisperModelLifecycle {}

@MainActor
final class iOSModelManager: ObservableObject {
    typealias DownloadClosure = @Sendable (URL, @escaping @Sendable (iOSModelDownloadProgressSnapshot) -> Void) async throws -> URL
    typealias UnzipClosure = @Sendable (URL, URL, FileManager, @escaping @Sendable (Int64, Int64) -> Void) async throws -> Void
    typealias FreeSpaceProvider = @Sendable (URL) -> Int64?

    @Published var installState: iOSModelInstallState = .notInstalled
    @Published var modelReady = false
    @Published var errorMessage: String?

    let fileManager: FileManager
    let whisperService: any iOSWhisperModelLifecycle
    let modelsDirectoryProvider: () -> URL?
    let ggmlModelURLProvider: () -> URL?
    let coreMLZipURLProvider: () -> URL?
    let coreMLDirectoryURLProvider: () -> URL?
    let manifestURLProvider: () -> URL?
    let download: DownloadClosure
    let unzip: UnzipClosure
    let freeSpaceProvider: FreeSpaceProvider
    let minGGMLBytes: Int64
    let requiredDownloadBytes: Int64
    let expectedGGMLSHA256: String
    let expectedCoreMLZipSHA256: String

    var currentDownloadTask: Task<Void, Never>?

    init(
        fileManager: FileManager = .default,
        whisperService: any iOSWhisperModelLifecycle,
        modelsDirectoryProvider: @escaping () -> URL? = { iOSSharedPaths.modelsDirectoryURL() },
        ggmlModelURLProvider: @escaping () -> URL? = { iOSSharedPaths.modelFileURL() },
        coreMLZipURLProvider: @escaping () -> URL? = { iOSSharedPaths.coreMLEncoderZipURL() },
        coreMLDirectoryURLProvider: @escaping () -> URL? = { iOSSharedPaths.coreMLEncoderDirectoryURL() },
        manifestURLProvider: @escaping () -> URL? = { iOSSharedPaths.modelInstallManifestURL() },
        minGGMLBytes: Int64 = iOSModelArtifacts.minGGMLBytes,
        requiredDownloadBytes: Int64 = 220_000_000,
        expectedGGMLSHA256: String = iOSModelArtifacts.ggmlBaseSHA256,
        expectedCoreMLZipSHA256: String = iOSModelArtifacts.coreMLZipSHA256,
        freeSpaceProvider: @escaping FreeSpaceProvider = defaultFreeSpaceProvider(at:),
        download: DownloadClosure? = nil,
        unzip: UnzipClosure? = nil
    ) {
        self.fileManager = fileManager
        self.whisperService = whisperService
        self.modelsDirectoryProvider = modelsDirectoryProvider
        self.ggmlModelURLProvider = ggmlModelURLProvider
        self.coreMLZipURLProvider = coreMLZipURLProvider
        self.coreMLDirectoryURLProvider = coreMLDirectoryURLProvider
        self.manifestURLProvider = manifestURLProvider
        self.minGGMLBytes = minGGMLBytes
        self.requiredDownloadBytes = requiredDownloadBytes
        self.expectedGGMLSHA256 = expectedGGMLSHA256
        self.expectedCoreMLZipSHA256 = expectedCoreMLZipSHA256
        self.freeSpaceProvider = freeSpaceProvider
        self.download = download ?? Self.defaultDownload(from:progress:)
        self.unzip = unzip ?? Self.defaultUnzip(zipURL:destinationDirectory:fileManager:progress:)

        Self.debugLog("Initialized model manager.")
        refreshStatus()
    }

    func refreshStatus() {
        guard let paths = resolvedPaths() else {
            Self.debugLog("refreshStatus: App Group container unavailable.")
            modelReady = false
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            return
        }

        let validation = validateInstall(paths: paths)
        Self.debugLog("""
        refreshStatus:
          modelsDirectory=\(paths.modelsDirectory.path)
          ggml=\(paths.ggmlModelURL.path)
          coreMLDir=\(paths.coreMLDirectoryURL.path)
          coreMLZip=\(paths.coreMLZipURL.path)
          manifest=\(paths.manifestURL.path)
          result=\(validation.debugDescription)
        """)

        switch validation {
        case .ready:
            modelReady = true
            installState = .ready
            errorMessage = nil
        case .notInstalled:
            modelReady = false
            installState = .notInstalled
            errorMessage = nil
        case .failed(let message):
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
        }
    }

    func downloadModel() {
        guard currentDownloadTask == nil else { return }
        currentDownloadTask = Task { [weak self] in
            await self?.performDownloadModel()
        }
    }

    func deleteModel() {
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        performDeleteModel()
    }

    func repairModelIfNeeded() {
        guard currentDownloadTask == nil else { return }
        currentDownloadTask = Task { [weak self] in
            await self?.performRepairModelIfNeeded()
        }
    }
}
