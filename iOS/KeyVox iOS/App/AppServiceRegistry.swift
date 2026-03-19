import Combine
import Foundation
import KeyVoxCore

@MainActor
final class AppServiceRegistry {
    static let shared = AppServiceRegistry()

    let dictionaryStore: DictionaryStore
    let settingsStore: AppSettingsStore
    let onboardingStore: OnboardingStore
    let weeklyWordStatsStore: WeeklyWordStatsStore
    let appHaptics: AppHaptics
    let whisperService: WhisperService
    let modelManager: ModelManager
    let postProcessor: TranscriptionPostProcessor
    let keyboardBridge: KeyVoxKeyboardBridge
    let transcriptionManager: TranscriptionManager
    let iCloudSyncCoordinator: CloudSyncCoordinator
    let weeklyWordStatsCloudSync: WeeklyWordStatsCloudSync
    let sessionLiveActivityCoordinator: KeyVoxSessionLiveActivityCoordinator
    let urlRouter: KeyVoxURLRouter

    private init(fileManager: FileManager = .default) {
        let dictionaryBaseDirectory = SharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager)
            ?? SharedPaths.fallbackBaseDirectoryURL(fileManager: fileManager)
        let settingsDefaults = SharedPaths.appGroupUserDefaults() ?? .standard
        let modelPathProvider = {
            SharedPaths.modelFileURL(fileManager: fileManager)?.path
        }
        let backgroundDownloadJobStore = ModelBackgroundDownloadJobStore(
            fileManager: fileManager,
            jobURLProvider: { SharedPaths.modelDownloadJobURL(fileManager: fileManager) }
        )
        let backgroundDownloadCoordinator = ModelBackgroundDownloadCoordinator(
            fileManager: fileManager,
            jobStore: backgroundDownloadJobStore,
            modelsDirectoryURLProvider: { SharedPaths.modelsDirectoryURL(fileManager: fileManager) },
            stagedGGMLURLProvider: { SharedPaths.stagedModelFileURL(fileManager: fileManager) },
            stagedCoreMLZipURLProvider: { SharedPaths.stagedCoreMLEncoderZipURL(fileManager: fileManager) }
        )
        let interruptedCaptureRecoveryStore = InterruptedCaptureRecoveryStore(
            fileManager: fileManager,
            recoveryURLProvider: { SharedPaths.interruptedCaptureRecoveryURL(fileManager: fileManager) }
        )

        let dictionaryStore = DictionaryStore(
            fileManager: fileManager,
            baseDirectoryURL: dictionaryBaseDirectory
        )
        let runtimeFlags = RuntimeFlags()
        let settingsStore = AppSettingsStore(defaults: settingsDefaults)
        let onboardingStore = OnboardingStore(defaults: settingsDefaults, runtimeFlags: runtimeFlags)
        let weeklyWordStatsStore = WeeklyWordStatsStore(defaults: settingsDefaults)
        let appHaptics = AppHaptics()
        let whisperService = WhisperService(modelPathResolver: modelPathProvider)
        let modelManager = ModelManager(
            fileManager: fileManager,
            whisperService: whisperService,
            modelsDirectoryProvider: { SharedPaths.modelsDirectoryURL(fileManager: fileManager) },
            ggmlModelURLProvider: { SharedPaths.modelFileURL(fileManager: fileManager) },
            coreMLZipURLProvider: { SharedPaths.coreMLEncoderZipURL(fileManager: fileManager) },
            coreMLDirectoryURLProvider: { SharedPaths.coreMLEncoderDirectoryURL(fileManager: fileManager) },
            manifestURLProvider: { SharedPaths.modelInstallManifestURL(fileManager: fileManager) },
            modelDownloadJobURLProvider: { SharedPaths.modelDownloadJobURL(fileManager: fileManager) },
            stagedGGMLURLProvider: { SharedPaths.stagedModelFileURL(fileManager: fileManager) },
            stagedCoreMLZipURLProvider: { SharedPaths.stagedCoreMLEncoderZipURL(fileManager: fileManager) },
            backgroundDownloadCoordinator: backgroundDownloadCoordinator
        )
        let postProcessor = TranscriptionPostProcessor()
        let keyboardBridge = KeyVoxKeyboardBridge()
        let recorder = AudioRecorder(
            preferBuiltInMicrophoneProvider: { [weak settingsStore] in
                settingsStore?.preferBuiltInMicrophone ?? true
            }
        )
        
        recorder.heartbeatCallback = { [weak keyboardBridge] in
            keyboardBridge?.touchHeartbeat()
        }
        recorder.liveMeterUpdateHandler = { [weak keyboardBridge] level, signalState in
            keyboardBridge?.publishLiveMeter(level: level, signalState: signalState)
        }

        let transcriptionManager = TranscriptionManager(
            recorder: recorder,
            transcriptionService: whisperService,
            dictionaryStore: dictionaryStore,
            weeklyWordStatsStore: weeklyWordStatsStore,
            postProcessor: postProcessor,
            keyboardBridge: keyboardBridge,
            interruptedCaptureRecoveryStore: interruptedCaptureRecoveryStore,
            modelPathProvider: modelPathProvider,
            autoParagraphsEnabledProvider: { [weak settingsStore] in
                settingsStore?.autoParagraphsEnabled ?? true
            },
            listFormattingEnabledProvider: { [weak settingsStore] in
                settingsStore?.listFormattingEnabled ?? true
            },
            capsLockEnabledProvider: {
                settingsDefaults.object(forKey: UserDefaultsKeys.capsLockEnabled) as? Bool ?? false
            },
            sessionDisableTimingProvider: { [weak settingsStore] in
                settingsStore?.sessionDisableTiming ?? .fiveMinutes
            },
            sessionDisableTimingPublisher: settingsStore.$sessionDisableTiming.eraseToAnyPublisher(),
            sessionPolicy: .default
        )
        let iCloudSyncCoordinator = CloudSyncCoordinator(
            settingsStore: settingsStore,
            dictionaryStore: dictionaryStore,
            defaults: settingsDefaults
        )
        let weeklyWordStatsCloudSync = WeeklyWordStatsCloudSync(
            weeklyWordStatsStore: weeklyWordStatsStore
        )
        let sessionLiveActivityCoordinator = KeyVoxSessionLiveActivityCoordinator(
            initialIsSessionActive: transcriptionManager.isSessionActive,
            initialSessionDisablePending: transcriptionManager.sessionDisablePending,
            initialLiveActivitiesEnabled: settingsStore.liveActivitiesEnabled,
            initialWeeklyWordCount: weeklyWordStatsStore.combinedWordCount,
            isSessionActivePublisher: transcriptionManager.$isSessionActive.eraseToAnyPublisher(),
            sessionDisablePendingPublisher: transcriptionManager.$sessionDisablePending.eraseToAnyPublisher(),
            liveActivitiesEnabledPublisher: settingsStore.$liveActivitiesEnabled.eraseToAnyPublisher(),
            weeklyWordCountPublisher: weeklyWordStatsStore.$snapshot
                .map(\.combinedWordCount)
                .eraseToAnyPublisher()
        )
        keyboardBridge.onStartRecordingCommand = {
            transcriptionManager.handleStartRecordingCommand()
        }
        keyboardBridge.onStopRecordingCommand = {
            transcriptionManager.handleStopRecordingCommand()
        }
        keyboardBridge.onCancelRecordingCommand = {
            transcriptionManager.cancelCurrentUtterance()
        }
        keyboardBridge.onDisableSessionCommand = {
            transcriptionManager.handleDisableSessionCommand()
        }
        recorder.audioInterruptedCaptureHandler = { [weak transcriptionManager] interruptedCapture in
            Task { @MainActor [weak transcriptionManager] in
                await transcriptionManager?.handleRecorderInterruptedCapture(interruptedCapture)
            }
        }
        recorder.audioSessionInterruptedHandler = { [weak transcriptionManager] in
            Task { @MainActor [weak transcriptionManager] in
                await transcriptionManager?.handleRecorderSessionInterrupted()
            }
        }
        keyboardBridge.registerObservers()

        self.dictionaryStore = dictionaryStore
        self.settingsStore = settingsStore
        self.onboardingStore = onboardingStore
        self.weeklyWordStatsStore = weeklyWordStatsStore
        self.appHaptics = appHaptics
        self.whisperService = whisperService
        self.modelManager = modelManager
        self.postProcessor = postProcessor
        self.keyboardBridge = keyboardBridge
        self.transcriptionManager = transcriptionManager
        self.iCloudSyncCoordinator = iCloudSyncCoordinator
        self.weeklyWordStatsCloudSync = weeklyWordStatsCloudSync
        self.sessionLiveActivityCoordinator = sessionLiveActivityCoordinator
        self.urlRouter = KeyVoxURLRouter(transcriptionManager: transcriptionManager)
    }
}
