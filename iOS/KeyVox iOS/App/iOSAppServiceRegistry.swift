import Foundation
import KeyVoxCore

@MainActor
final class iOSAppServiceRegistry {
    static let shared = iOSAppServiceRegistry()

    let dictionaryStore: DictionaryStore
    let settingsStore: iOSAppSettingsStore
    let whisperService: WhisperService
    let modelManager: iOSModelManager
    let postProcessor: TranscriptionPostProcessor
    let keyboardBridge: KeyVoxKeyboardBridge
    let artifactWriter: Phase2CaptureArtifactWriter
    let transcriptionManager: iOSTranscriptionManager
    let iCloudSyncCoordinator: iOSiCloudSyncCoordinator
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
        let recorder = iOSAudioRecorder()
        
        recorder.heartbeatCallback = { [weak keyboardBridge] in
            keyboardBridge?.touchHeartbeat()
        }

        let artifactWriter = Phase2CaptureArtifactWriter()
        let transcriptionManager = iOSTranscriptionManager(
            recorder: recorder,
            artifactWriter: artifactWriter,
            transcriptionService: whisperService,
            dictionaryStore: dictionaryStore,
            postProcessor: postProcessor,
            keyboardBridge: keyboardBridge,
            modelPathProvider: modelPathProvider,
            autoParagraphsEnabledProvider: { [weak settingsStore] in
                settingsStore?.autoParagraphsEnabled ?? true
            },
            listFormattingEnabledProvider: { [weak settingsStore] in
                settingsStore?.listFormattingEnabled ?? true
            }
        )
        let iCloudSyncCoordinator = iOSiCloudSyncCoordinator(
            settingsStore: settingsStore,
            dictionaryStore: dictionaryStore,
            defaults: settingsDefaults
        )
        keyboardBridge.onStartRecordingCommand = {
            transcriptionManager.handleStartRecordingCommand()
        }
        keyboardBridge.onStopRecordingCommand = {
            transcriptionManager.handleStopRecordingCommand()
        }
        keyboardBridge.registerObservers()

        self.dictionaryStore = dictionaryStore
        self.settingsStore = settingsStore
        self.whisperService = whisperService
        self.modelManager = modelManager
        self.postProcessor = postProcessor
        self.keyboardBridge = keyboardBridge
        self.artifactWriter = artifactWriter
        self.transcriptionManager = transcriptionManager
        self.iCloudSyncCoordinator = iCloudSyncCoordinator
        self.urlRouter = KeyVoxURLRouter(transcriptionManager: transcriptionManager)
    }
}
