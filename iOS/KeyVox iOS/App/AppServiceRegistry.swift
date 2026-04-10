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
    let parakeetService: ParakeetService
    let activeProviderRouter: SwitchableDictationProvider
    let modelManager: ModelManager
    let postProcessor: TranscriptionPostProcessor
    let keyboardBridge: KeyVoxKeyboardBridge
    let transcriptionManager: TranscriptionManager
    let iCloudSyncCoordinator: CloudSyncCoordinator
    let weeklyWordStatsCloudSync: WeeklyWordStatsCloudSync
    let sessionLiveActivityCoordinator: KeyVoxSessionLiveActivityCoordinator
    let appUpdateCoordinator: AppUpdateCoordinator
    let urlRouter: KeyVoxURLRouter
    private var cancellables = Set<AnyCancellable>()

    private init(fileManager: FileManager = .default) {
        let dictionaryBaseDirectory = SharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager)
            ?? SharedPaths.fallbackBaseDirectoryURL(fileManager: fileManager)
        let settingsDefaults = SharedPaths.appGroupUserDefaults() ?? .standard
        let modelLocator = InstalledDictationModelLocator(
            fileManager: fileManager,
            modelsDirectoryURL: SharedPaths.modelsDirectoryURL(fileManager: fileManager)
        )
        let backgroundDownloadJobStore = ModelBackgroundDownloadJobStore(
            fileManager: fileManager,
            jobURLProvider: { SharedPaths.modelDownloadJobURL(fileManager: fileManager) }
        )
        let backgroundDownloadCoordinator = ModelBackgroundDownloadCoordinator(
            fileManager: fileManager,
            jobStore: backgroundDownloadJobStore,
            modelLocator: modelLocator
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
        let whisperService = WhisperService(modelPathResolver: modelLocator.resolvedWhisperModelPath)
        let parakeetService = ParakeetService(modelURLResolver: modelLocator.resolvedParakeetModelDirectoryURL)
        let activeProviderRouter = SwitchableDictationProvider(initialProvider: whisperService)
        let modelManager = ModelManager(
            fileManager: fileManager,
            modelLocator: modelLocator,
            backgroundJobStore: backgroundDownloadJobStore,
            lifecycleProvider: { modelID in
                switch modelID {
                case .whisperBase:
                    return whisperService
                case .parakeetTdtV3:
                    return parakeetService
                }
            },
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
            transcriptionService: activeProviderRouter,
            dictionaryStore: dictionaryStore,
            weeklyWordStatsStore: weeklyWordStatsStore,
            postProcessor: postProcessor,
            keyboardBridge: keyboardBridge,
            interruptedCaptureRecoveryStore: interruptedCaptureRecoveryStore,
            modelPathProvider: modelLocator.resolvedWhisperModelPath,
            modelAvailabilityProvider: { [weak activeProviderRouter] in
                activeProviderRouter?.isModelReady ?? false
            },
            missingModelMessageProvider: { [weak settingsStore] in
                settingsStore?.activeDictationProvider.missingModelMessage ?? "Required dictation model not found."
            },
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
        let appUpdateCoordinator = AppUpdateCoordinator(defaults: settingsDefaults)
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
        self.parakeetService = parakeetService
        self.activeProviderRouter = activeProviderRouter
        self.modelManager = modelManager
        self.postProcessor = postProcessor
        self.keyboardBridge = keyboardBridge
        self.transcriptionManager = transcriptionManager
        self.iCloudSyncCoordinator = iCloudSyncCoordinator
        self.weeklyWordStatsCloudSync = weeklyWordStatsCloudSync
        self.sessionLiveActivityCoordinator = sessionLiveActivityCoordinator
        self.appUpdateCoordinator = appUpdateCoordinator
        self.urlRouter = KeyVoxURLRouter(transcriptionManager: transcriptionManager)

        settingsStore.$activeDictationProvider
            .removeDuplicates()
            .sink { [weak self] provider in
                self?.applyActiveProviderSelection(provider)
            }
            .store(in: &cancellables)

        modelManager.$modelStates
            .sink { [weak self] _ in
                self?.normalizeActiveProviderSelection()
            }
            .store(in: &cancellables)

        normalizeActiveProviderSelection()
        applyActiveProviderSelection(settingsStore.activeDictationProvider)
    }

    private func applyActiveProviderSelection(_ provider: AppSettingsStore.ActiveDictationProvider) {
        let activeProvider: any DictationProvider = switch provider {
        case .whisper:
            whisperService
        case .parakeet:
            parakeetService
        }

        activeProviderRouter.replaceActiveProvider(
            with: activeProvider,
            warmNewProviderIfReady: false
        )

        if provider == .parakeet {
            Task { [weak self] in
                await self?.parakeetService.preloadIfNeeded()
            }
        }
    }

    private func normalizeActiveProviderSelection() {
        let selectableProviders = AppSettingsStore.ActiveDictationProvider.allCases.filter {
            modelManager.isModelReady(for: $0.modelID)
        }

        guard selectableProviders.contains(settingsStore.activeDictationProvider) else {
            if let fallback = selectableProviders.first {
                settingsStore.activeDictationProvider = fallback
            } else if settingsStore.activeDictationProvider != .whisper {
                settingsStore.activeDictationProvider = .whisper
            }
            return
        }
    }
}
