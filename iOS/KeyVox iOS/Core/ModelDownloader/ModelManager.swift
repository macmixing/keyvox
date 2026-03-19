import Combine
import Foundation
import KeyVoxCore

@MainActor
protocol WhisperModelLifecycle: AnyObject {
    func warmup()
    func unloadModel()
}

extension WhisperService: WhisperModelLifecycle {}

@MainActor
final class ModelManager: ObservableObject {
    typealias DownloadClosure = @Sendable (URL, @escaping @Sendable (ModelDownloadProgressSnapshot) -> Void) async throws -> URL
    typealias UnzipClosure = @Sendable (URL, URL, FileManager, @escaping @Sendable (Int64, Int64) -> Void) async throws -> Void
    typealias FreeSpaceProvider = @Sendable (URL) -> Int64?

    @Published var installState: ModelInstallState = .notInstalled
    @Published var modelReady = false
    @Published var errorMessage: String?

    let fileManager: FileManager
    let whisperService: any WhisperModelLifecycle
    let modelsDirectoryProvider: () -> URL?
    let ggmlModelURLProvider: () -> URL?
    let coreMLZipURLProvider: () -> URL?
    let coreMLDirectoryURLProvider: () -> URL?
    let manifestURLProvider: () -> URL?
    let modelDownloadJobURLProvider: () -> URL?
    let stagedGGMLURLProvider: () -> URL?
    let stagedCoreMLZipURLProvider: () -> URL?
    let download: DownloadClosure
    let unzip: UnzipClosure
    let freeSpaceProvider: FreeSpaceProvider
    let backgroundDownloadCoordinator: ModelBackgroundDownloadCoordinator?
    let minGGMLBytes: Int64
    let requiredDownloadBytes: Int64
    let expectedGGMLSHA256: String
    let expectedCoreMLZipSHA256: String

    var currentDownloadTask: Task<Void, Never>?
    var appIsActive = false
    var isFinalizationInFlight = false

    init(
        fileManager: FileManager = .default,
        whisperService: any WhisperModelLifecycle,
        modelsDirectoryProvider: @escaping () -> URL? = { SharedPaths.modelsDirectoryURL() },
        ggmlModelURLProvider: @escaping () -> URL? = { SharedPaths.modelFileURL() },
        coreMLZipURLProvider: @escaping () -> URL? = { SharedPaths.coreMLEncoderZipURL() },
        coreMLDirectoryURLProvider: @escaping () -> URL? = { SharedPaths.coreMLEncoderDirectoryURL() },
        manifestURLProvider: @escaping () -> URL? = { SharedPaths.modelInstallManifestURL() },
        modelDownloadJobURLProvider: @escaping () -> URL? = { SharedPaths.modelDownloadJobURL() },
        stagedGGMLURLProvider: @escaping () -> URL? = { SharedPaths.stagedModelFileURL() },
        stagedCoreMLZipURLProvider: @escaping () -> URL? = { SharedPaths.stagedCoreMLEncoderZipURL() },
        minGGMLBytes: Int64 = ModelArtifacts.minGGMLBytes,
        requiredDownloadBytes: Int64 = 220_000_000,
        expectedGGMLSHA256: String = ModelArtifacts.ggmlBaseSHA256,
        expectedCoreMLZipSHA256: String = ModelArtifacts.coreMLZipSHA256,
        freeSpaceProvider: @escaping FreeSpaceProvider = defaultFreeSpaceProvider(at:),
        backgroundDownloadCoordinator: ModelBackgroundDownloadCoordinator? = nil,
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
        self.modelDownloadJobURLProvider = modelDownloadJobURLProvider
        self.stagedGGMLURLProvider = stagedGGMLURLProvider
        self.stagedCoreMLZipURLProvider = stagedCoreMLZipURLProvider
        self.minGGMLBytes = minGGMLBytes
        self.requiredDownloadBytes = requiredDownloadBytes
        self.expectedGGMLSHA256 = expectedGGMLSHA256
        self.expectedCoreMLZipSHA256 = expectedCoreMLZipSHA256
        self.freeSpaceProvider = freeSpaceProvider
        self.backgroundDownloadCoordinator = backgroundDownloadCoordinator
        self.download = download ?? Self.defaultDownload(from:progress:)
        self.unzip = unzip ?? Self.defaultUnzip(zipURL:destinationDirectory:fileManager:progress:)

        Self.debugLog("Initialized model manager.")
        self.backgroundDownloadCoordinator?.stateDidChange = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleBackgroundDownloadStateChanged()
            }
        }
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

        if let backgroundJob = persistedBackgroundDownloadJob() {
            applyBackgroundJobStatus(backgroundJob)
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
            guard let self else { return }
            if self.backgroundDownloadCoordinator == nil {
                await self.performDownloadModel()
            } else {
                await self.startOrResumeDownloadJob()
            }
        }
    }

    func deleteModel() {
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        if let backgroundDownloadCoordinator {
            Task {
                await backgroundDownloadCoordinator.clearJob()
            }
        }
        performDeleteModel()
    }

    func repairModelIfNeeded() {
        guard currentDownloadTask == nil else { return }
        currentDownloadTask = Task { [weak self] in
            await self?.performRepairModelIfNeeded()
        }
    }

    func handleAppDidBecomeActive() {
        appIsActive = true
        Task { [weak self] in
            guard let self else { return }
            await self.recoverInterruptedDownloadIfNeeded()
        }
    }

    func handleAppDidEnterBackground() {
        appIsActive = false
    }

    func handleBackgroundURLSessionEvents(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == ModelBackgroundDownloadCoordinator.sessionIdentifier else {
            completionHandler()
            return
        }

        guard let backgroundDownloadCoordinator else {
            completionHandler()
            return
        }

        backgroundDownloadCoordinator.registerBackgroundSessionCompletionHandler(completionHandler)
    }

    func handleBestEffortBackgroundRepair() async {
        guard let backgroundDownloadCoordinator else { return }
        _ = await backgroundDownloadCoordinator.synchronizeWithSystemTasks()
        refreshStatus()
    }

    private func handleBackgroundDownloadStateChanged() async {
        refreshStatus()
        await resumeForegroundFinalizationIfNeeded()
    }

    private func recoverInterruptedDownloadIfNeeded() async {
        guard let backgroundDownloadCoordinator else {
            refreshStatus()
            return
        }

        let synchronizedJob = await backgroundDownloadCoordinator.synchronizeWithSystemTasks()
        refreshStatus()

        guard currentDownloadTask == nil,
              let synchronizedJob,
              synchronizedJob.finalizationState != .failed else {
            await resumeForegroundFinalizationIfNeeded()
            return
        }

        if synchronizedJob.isReadyForFinalization {
            await resumeForegroundFinalizationIfNeeded()
            return
        }

        await startOrResumeDownloadJob()
    }
}
