import AVFAudio
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
    let appTabRouter: AppTabRouter
    let appHaptics: AppHaptics
    let ttsPurchaseController: TTSPurchaseController
    let keyVoxSpeakIntroController: KeyVoxSpeakIntroController
    let ttsPreviewPlayer: TTSPreviewPlayer
    let whisperService: WhisperService
    let parakeetService: ParakeetService
    let activeProviderRouter: SwitchableDictationProvider
    let ttsManager: TTSManager
    let pocketTTSModelManager: PocketTTSModelManager
    let audioModeCoordinator: AudioModeCoordinator
    let modelManager: ModelManager
    let postProcessor: TranscriptionPostProcessor
    let keyboardBridge: KeyVoxKeyboardBridge
    let transcriptionManager: TranscriptionManager
    let iCloudSyncCoordinator: CloudSyncCoordinator
    let weeklyWordStatsCloudSync: WeeklyWordStatsCloudSync
    let sessionLiveActivityCoordinator: KeyVoxSessionLiveActivityCoordinator
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
        let appTabRouter = AppTabRouter()
        let appHaptics = AppHaptics()
        let ttsPurchaseController = TTSPurchaseController(
            defaults: settingsDefaults,
            bypassFreeSpeakLimit: runtimeFlags.bypassTTSFreeSpeakLimit
        )
        let keyVoxSpeakIntroController = KeyVoxSpeakIntroController(
            defaults: settingsDefaults,
            forcePresentation: runtimeFlags.forceKeyVoxSpeakIntro
        )
        let ttsPreviewPlayer = TTSPreviewPlayer(appHaptics: appHaptics)
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
        
        recorder.heartbeatCallback = { [weak keyboardBridge, weak recorder] in
            let hasBluetoothAudioRoute = recorder?.audioSession.currentRoute.inputs.contains(where: {
                $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE
            }) == true || recorder?.audioSession.currentRoute.outputs.contains(where: {
                $0.portType == .bluetoothA2DP || $0.portType == .bluetoothHFP || $0.portType == .bluetoothLE
            }) == true
            keyboardBridge?.touchHeartbeat(sessionHasBluetoothAudioRoute: hasBluetoothAudioRoute)
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
        let ttsPlaybackCoordinator = TTSPlaybackCoordinator()
        let ttsEngine = PocketTTSEngine(fileManager: fileManager)
        let pocketTTSModelManager = PocketTTSModelManager(fileManager: fileManager)
        let ttsManager = TTSManager(
            settingsStore: settingsStore,
            appHaptics: appHaptics,
            keyboardBridge: keyboardBridge,
            engine: ttsEngine,
            playbackCoordinator: ttsPlaybackCoordinator,
            purchaseGate: ttsPurchaseController,
            effectiveVoiceProvider: { [weak settingsStore, weak pocketTTSModelManager] in
                guard let settingsStore else { return .azelma }
                guard let pocketTTSModelManager else { return settingsStore.ttsVoice }
                return Self.resolvedTTSVoiceSelection(
                    selectedVoice: settingsStore.ttsVoice,
                    pocketTTSModelManager: pocketTTSModelManager
                )
            },
            onNewGenerationPlaybackStarted: { [weak keyVoxSpeakIntroController] in
                keyVoxSpeakIntroController?.markFeatureUsed()
            }
        )
        let audioModeCoordinator = AudioModeCoordinator(
            transcriptionManager: transcriptionManager,
            ttsManager: ttsManager,
            appTabRouter: appTabRouter,
            ttsPurchaseGate: ttsPurchaseController
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
            audioModeCoordinator.handleStartRecordingCommand()
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
        keyboardBridge.onStartTTSCommand = {
            audioModeCoordinator.handleStartTTSFromPendingRequest()
        }
        keyboardBridge.onStopTTSCommand = {
            audioModeCoordinator.handleStopTTS()
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
        self.appTabRouter = appTabRouter
        self.appHaptics = appHaptics
        self.ttsPurchaseController = ttsPurchaseController
        self.keyVoxSpeakIntroController = keyVoxSpeakIntroController
        self.ttsPreviewPlayer = ttsPreviewPlayer
        self.whisperService = whisperService
        self.parakeetService = parakeetService
        self.activeProviderRouter = activeProviderRouter
        self.ttsManager = ttsManager
        self.pocketTTSModelManager = pocketTTSModelManager
        self.audioModeCoordinator = audioModeCoordinator
        self.modelManager = modelManager
        self.postProcessor = postProcessor
        self.keyboardBridge = keyboardBridge
        self.transcriptionManager = transcriptionManager
        self.iCloudSyncCoordinator = iCloudSyncCoordinator
        self.weeklyWordStatsCloudSync = weeklyWordStatsCloudSync
        self.sessionLiveActivityCoordinator = sessionLiveActivityCoordinator
        self.urlRouter = KeyVoxURLRouter(
            transcriptionManager: transcriptionManager,
            ttsManager: ttsManager,
            audioModeCoordinator: audioModeCoordinator
        )

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

        pocketTTSModelManager.$voiceInstallStates
            .sink { [weak self] _ in
                self?.normalizeTTSVoiceSelection()
            }
            .store(in: &cancellables)

        pocketTTSModelManager.$sharedModelInstallState
            .sink { [weak self] _ in
                self?.normalizeTTSVoiceSelection()
            }
            .store(in: &cancellables)

        normalizeActiveProviderSelection()
        normalizeTTSVoiceSelection()
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

    private func normalizeTTSVoiceSelection() {
        let resolvedVoice = Self.resolvedTTSVoiceSelection(
            selectedVoice: settingsStore.ttsVoice,
            pocketTTSModelManager: pocketTTSModelManager
        )
        guard settingsStore.ttsVoice != resolvedVoice else { return }
        settingsStore.ttsVoice = resolvedVoice
    }

    private static func resolvedTTSVoiceSelection(
        selectedVoice: AppSettingsStore.TTSVoice,
        pocketTTSModelManager: PocketTTSModelManager
    ) -> AppSettingsStore.TTSVoice {
        if pocketTTSModelManager.isVoiceReady(selectedVoice) {
            return selectedVoice
        }

        return pocketTTSModelManager.installedVoices().first ?? selectedVoice
    }
}
