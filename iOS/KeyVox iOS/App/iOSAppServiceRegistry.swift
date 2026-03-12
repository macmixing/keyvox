import Foundation
import KeyVoxCore

@MainActor
final class iOSAppServiceRegistry {
    static let shared = iOSAppServiceRegistry()

    let dictionaryStore: DictionaryStore
    let settingsStore: iOSAppSettingsStore
    let weeklyWordStatsStore: iOSWeeklyWordStatsStore
    let whisperService: WhisperService
    let modelManager: iOSModelManager
    let postProcessor: TranscriptionPostProcessor
    let keyboardBridge: KeyVoxKeyboardBridge
    let transcriptionManager: iOSTranscriptionManager
    let iCloudSyncCoordinator: iOSiCloudSyncCoordinator
    let weeklyWordStatsCloudSync: iOSWeeklyWordStatsCloudSync
    let urlRouter: KeyVoxURLRouter

    private init(fileManager: FileManager = .default) {
        let dictionaryBaseDirectory = iOSSharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager)
            ?? iOSSharedPaths.fallbackBaseDirectoryURL(fileManager: fileManager)
        let settingsDefaults = iOSSharedPaths.appGroupUserDefaults() ?? .standard
        let modelPathProvider = {
            iOSSharedPaths.modelFileURL(fileManager: fileManager)?.path
        }

        let dictionaryStore = DictionaryStore(
            fileManager: fileManager,
            baseDirectoryURL: dictionaryBaseDirectory
        )
        let settingsStore = iOSAppSettingsStore(defaults: settingsDefaults)
        let weeklyWordStatsStore = iOSWeeklyWordStatsStore(defaults: settingsDefaults)
        let whisperService = WhisperService(modelPathResolver: modelPathProvider)
        let modelManager = iOSModelManager(
            fileManager: fileManager,
            whisperService: whisperService,
            modelsDirectoryProvider: { iOSSharedPaths.modelsDirectoryURL(fileManager: fileManager) },
            ggmlModelURLProvider: { iOSSharedPaths.modelFileURL(fileManager: fileManager) },
            coreMLZipURLProvider: { iOSSharedPaths.coreMLEncoderZipURL(fileManager: fileManager) },
            coreMLDirectoryURLProvider: { iOSSharedPaths.coreMLEncoderDirectoryURL(fileManager: fileManager) }
        )
        let postProcessor = TranscriptionPostProcessor()
        let keyboardBridge = KeyVoxKeyboardBridge()
        let recorder = iOSAudioRecorder(
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

        let transcriptionManager = iOSTranscriptionManager(
            recorder: recorder,
            transcriptionService: whisperService,
            dictionaryStore: dictionaryStore,
            weeklyWordStatsStore: weeklyWordStatsStore,
            postProcessor: postProcessor,
            keyboardBridge: keyboardBridge,
            modelPathProvider: modelPathProvider,
            autoParagraphsEnabledProvider: { [weak settingsStore] in
                settingsStore?.autoParagraphsEnabled ?? true
            },
            listFormattingEnabledProvider: { [weak settingsStore] in
                settingsStore?.listFormattingEnabled ?? true
            },
            capsLockEnabledProvider: {
                settingsDefaults.object(forKey: iOSUserDefaultsKeys.capsLockEnabled) as? Bool ?? false
            },
            sessionPolicy: .default
        )
        let iCloudSyncCoordinator = iOSiCloudSyncCoordinator(
            settingsStore: settingsStore,
            dictionaryStore: dictionaryStore,
            defaults: settingsDefaults
        )
        let weeklyWordStatsCloudSync = iOSWeeklyWordStatsCloudSync(
            weeklyWordStatsStore: weeklyWordStatsStore
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
        recorder.audioInterruptedCaptureHandler = { [weak transcriptionManager] interruptedCapture in
            Task { @MainActor [weak transcriptionManager] in
                await transcriptionManager?.handleRecorderInterruptedCapture(interruptedCapture)
            }
        }
        keyboardBridge.registerObservers()

        self.dictionaryStore = dictionaryStore
        self.settingsStore = settingsStore
        self.weeklyWordStatsStore = weeklyWordStatsStore
        self.whisperService = whisperService
        self.modelManager = modelManager
        self.postProcessor = postProcessor
        self.keyboardBridge = keyboardBridge
        self.transcriptionManager = transcriptionManager
        self.iCloudSyncCoordinator = iCloudSyncCoordinator
        self.weeklyWordStatsCloudSync = weeklyWordStatsCloudSync
        self.urlRouter = KeyVoxURLRouter(transcriptionManager: transcriptionManager)
    }
}
