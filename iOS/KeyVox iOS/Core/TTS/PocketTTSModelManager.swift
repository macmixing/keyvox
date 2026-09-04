import Combine
import Foundation

enum PocketTTSInstallState: Equatable {
    case notInstalled
    case downloading(progress: Double)
    case installing(progress: Double)
    case ready
    case failed(String)

    var statusText: String {
        switch self {
        case .notInstalled:
            return "Not installed"
        case .downloading:
            return "Downloading playback model"
        case .installing:
            return "Installing playback model"
        case .ready:
            return "Installed"
        case .failed:
            return "Install failed"
        }
    }
}

enum PocketTTSInstallTarget: Equatable {
    case sharedModel
    case voice(AppSettingsStore.TTSVoice)
}

@MainActor
final class PocketTTSModelManager: ObservableObject {
    @Published var sharedModelInstallState: PocketTTSInstallState = .notInstalled
    @Published var voiceInstallStates: [AppSettingsStore.TTSVoice: PocketTTSInstallState]
    @Published var activeInstallTarget: PocketTTSInstallTarget?

    let fileManager: FileManager
    let session: URLSession
    let assetLocator: PocketTTSAssetLocator
    let backgroundDownloadCoordinator: PocketTTSBackgroundDownloadCoordinator
    var installTask: Task<Void, Never>?
    var pendingVoiceInstallAfterSharedModel: AppSettingsStore.TTSVoice?
    var onDidInvalidateInstalledAssets: (() -> Void)?
    var appIsActive = false
    var isFinalizationInFlight = false

    init(
        fileManager: FileManager = .default,
        session: URLSession = .shared,
        assetLocator: PocketTTSAssetLocator? = nil,
        backgroundDownloadCoordinator: PocketTTSBackgroundDownloadCoordinator
    ) {
        self.fileManager = fileManager
        self.session = session
        self.assetLocator = assetLocator ?? PocketTTSAssetLocator(fileManager: fileManager)
        self.backgroundDownloadCoordinator = backgroundDownloadCoordinator
        self.voiceInstallStates = Dictionary(
            uniqueKeysWithValues: AppSettingsStore.TTSVoice.userFacingCases.map { ($0, .notInstalled) }
        )
        self.backgroundDownloadCoordinator.stateDidChange = { [weak self] job in
            Task { @MainActor [weak self] in
                await self?.handleBackgroundDownloadStateChanged(job)
            }
        }
        refreshStatus()
    }

    var installState: PocketTTSInstallState {
        sharedModelInstallState
    }

    func installState(for voice: AppSettingsStore.TTSVoice) -> PocketTTSInstallState {
        voiceInstallStates[voice] ?? .notInstalled
    }

    func refreshStatus() {
        guard installTask == nil else { return }
        sharedModelInstallState = assetLocator.isSharedModelInstalled() ? .ready : .notInstalled
        for voice in AppSettingsStore.TTSVoice.userFacingCases {
            voiceInstallStates[voice] = assetLocator.isVoiceInstalled(voice) ? .ready : .notInstalled
        }

        guard let job = backgroundDownloadCoordinator.loadJob() else {
            activeInstallTarget = nil
            return
        }
        activeInstallTarget = job.target
        applyBackgroundJobState(job)
    }

    func handleAppDidBecomeActive() {
        appIsActive = true
        Task { [weak self] in
            guard let self else { return }
            await self.backgroundDownloadCoordinator.handleAppDidBecomeActive()
            guard self.appIsActive else { return }
            let job = await self.backgroundDownloadCoordinator.synchronizeWithSystemTasks()
            if let job,
               !job.isReadyForFinalization,
               job.finalizationState != .failed {
                try? await self.backgroundDownloadCoordinator.startOrResumeJob(job)
            }
            self.refreshStatus()
            await self.resumeForegroundFinalizationIfNeeded()
        }
    }

    func handleAppWillResignActive() {
        appIsActive = false
        backgroundDownloadCoordinator.handleAppWillResignActive()
    }

    func handleBackgroundURLSessionEvents(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == PocketTTSBackgroundDownloadCoordinator.sessionIdentifier else {
            completionHandler()
            return
        }
        backgroundDownloadCoordinator.registerBackgroundSessionCompletionHandler(completionHandler)
    }

    func isSharedModelReady() -> Bool {
        if case .ready = sharedModelInstallState {
            return true
        }
        return false
    }

    func isVoiceReady(_ voice: AppSettingsStore.TTSVoice) -> Bool {
        if case .ready = installState(for: voice) {
            return true
        }
        return false
    }

    func isReady(for voice: AppSettingsStore.TTSVoice) -> Bool {
        isSharedModelReady() && isVoiceReady(voice)
    }

    func installedVoices() -> [AppSettingsStore.TTSVoice] {
        AppSettingsStore.TTSVoice.userFacingCases.filter { voice in
            if case .ready = installState(for: voice) {
                return true
            }
            return false
        }
    }

    func isBusyInstallingAnotherTarget(sharedModel: Bool = false, voice: AppSettingsStore.TTSVoice? = nil) -> Bool {
        guard let activeInstallTarget else { return false }
        if sharedModel {
            return activeInstallTarget != .sharedModel
        }
        if let voice {
            return activeInstallTarget != .voice(voice)
        }
        return true
    }

    func downloadModel() {
        downloadSharedModel()
    }
}
