import Combine
import Foundation
import KeyVoxCore

@MainActor
final class ModelManager: ObservableObject {
    typealias DownloadClosure = @Sendable (URL, @escaping @Sendable (ModelDownloadProgressSnapshot) -> Void) async throws -> URL
    typealias UnzipClosure = @Sendable (URL, URL, FileManager, @escaping @Sendable (Int64, Int64) -> Void) async throws -> Void
    typealias FreeSpaceProvider = @Sendable (URL) -> Int64?
    typealias LifecycleProvider = @MainActor (DictationModelID) -> (any DictationModelLifecycleProviding)?

    @Published private(set) var modelStates: [DictationModelID: ModelInstallState]
    @Published var installState: ModelInstallState = .notInstalled
    @Published var modelReady = false
    @Published var errorMessage: String?

    let fileManager: FileManager
    let modelLocator: InstalledDictationModelLocator
    let backgroundJobStoreInstance: ModelBackgroundDownloadJobStore
    let lifecycleProvider: LifecycleProvider
    let descriptorProvider: (DictationModelID) -> DictationModelDescriptor
    let download: DownloadClosure
    let unzip: UnzipClosure
    let freeSpaceProvider: FreeSpaceProvider
    let backgroundDownloadCoordinator: ModelBackgroundDownloadCoordinator?

    var currentDownloadTask: Task<Void, Never>?
    var appIsActive = false
    var isFinalizationInFlight = false

    init(
        fileManager: FileManager = .default,
        modelLocator: InstalledDictationModelLocator,
        backgroundJobStore: ModelBackgroundDownloadJobStore? = nil,
        lifecycleProvider: @escaping LifecycleProvider,
        descriptorProvider: @escaping (DictationModelID) -> DictationModelDescriptor = DictationModelCatalog.descriptor(for:),
        freeSpaceProvider: @escaping FreeSpaceProvider = defaultFreeSpaceProvider(at:),
        backgroundDownloadCoordinator: ModelBackgroundDownloadCoordinator? = nil,
        download: DownloadClosure? = nil,
        unzip: UnzipClosure? = nil
    ) {
        self.fileManager = fileManager
        self.modelLocator = modelLocator
        self.backgroundJobStoreInstance = backgroundJobStore ?? ModelBackgroundDownloadJobStore(
            fileManager: fileManager,
            jobURLProvider: { SharedPaths.modelDownloadJobURL(fileManager: fileManager) }
        )
        self.lifecycleProvider = lifecycleProvider
        self.descriptorProvider = descriptorProvider
        self.freeSpaceProvider = freeSpaceProvider
        self.backgroundDownloadCoordinator = backgroundDownloadCoordinator
        self.download = download ?? Self.defaultDownload(from:progress:)
        self.unzip = unzip ?? Self.defaultUnzip(zipURL:destinationDirectory:fileManager:progress:)
        self.modelStates = Dictionary(
            uniqueKeysWithValues: DictationModelID.allCases.map { ($0, .notInstalled) }
        )

        Self.debugLog("Initialized model manager.")
        self.backgroundDownloadCoordinator?.stateDidChange = { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.handleBackgroundDownloadStateChanged()
            }
        }
        refreshStatus()
    }

    func state(for modelID: DictationModelID) -> ModelInstallState {
        modelStates[modelID] ?? .notInstalled
    }

    func isModelReady(for modelID: DictationModelID) -> Bool {
        if case .ready = state(for: modelID) {
            return true
        }
        return false
    }

    func activeInstallModelID() -> DictationModelID? {
        for modelID in DictationModelID.allCases {
            switch state(for: modelID) {
            case .downloading, .installing:
                return modelID
            default:
                continue
            }
        }

        if let backgroundJob = persistedBackgroundDownloadJob(),
           backgroundJob.finalizationState != .failed {
            return backgroundJob.modelID
        }

        return nil
    }

    func refreshStatus() {
        for modelID in DictationModelID.allCases {
            modelStates[modelID] = validatedState(for: modelID)
        }

        if let backgroundJob = persistedBackgroundDownloadJob() {
            applyBackgroundJobStatus(backgroundJob)
        }

        syncLegacyWhisperState()
    }

    func downloadModel(withID modelID: DictationModelID) {
        if let activeInstallModelID = activeInstallModelID(), activeInstallModelID != modelID {
            return
        }

        guard currentDownloadTask == nil else { return }
        currentDownloadTask = Task { [weak self] in
            guard let self else { return }
            if self.backgroundDownloadCoordinator == nil {
                await self.performDownloadModel(withID: modelID)
            } else {
                await self.startOrResumeDownloadJob(for: modelID)
            }
        }
    }

    func downloadModel() {
        downloadModel(withID: .whisperBase)
    }

    func deleteModel(withID modelID: DictationModelID) {
        currentDownloadTask?.cancel()
        currentDownloadTask = nil
        if let backgroundDownloadCoordinator,
           backgroundDownloadCoordinator.loadJob()?.modelID == modelID {
            Task { [weak self] in
                await self?.performDeleteModel(withID: modelID)
            }
        } else {
            performDeleteModelSynchronously(withID: modelID)
        }
    }

    func deleteModel() {
        deleteModel(withID: .whisperBase)
    }

    func repairModelIfNeeded(for modelID: DictationModelID) {
        if let activeInstallModelID = activeInstallModelID(), activeInstallModelID != modelID {
            return
        }

        guard currentDownloadTask == nil else { return }
        currentDownloadTask = Task { [weak self] in
            await self?.performRepairModelIfNeeded(for: modelID)
        }
    }

    func repairModelIfNeeded() {
        repairModelIfNeeded(for: .whisperBase)
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

    func firstInstalledModelID() -> DictationModelID? {
        DictationModelID.allCases.first(where: isModelReady(for:))
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

        await startOrResumeDownloadJob(for: synchronizedJob.modelID)
    }

    func setState(_ state: ModelInstallState, for modelID: DictationModelID) {
        modelStates[modelID] = state
        syncLegacyWhisperState()
    }

    private func syncLegacyWhisperState() {
        let whisperState = state(for: .whisperBase)
        installState = whisperState
        modelReady = isModelReady(for: .whisperBase)
        if case .failed(let message) = whisperState {
            errorMessage = message
        } else {
            errorMessage = nil
        }
    }
}
