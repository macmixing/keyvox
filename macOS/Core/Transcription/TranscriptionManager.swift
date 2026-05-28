import SwiftUI
import Combine
import KeyVoxCore
import KeyVoxStyleRewrite

@MainActor
class TranscriptionManager: ObservableObject {
    @Published var state: AppState = .idle
    @Published var lastTranscription: String = UserDefaults.standard.string(
        forKey: UserDefaultsKeys.App.lastTranscription
    ) ?? ""
    @Published var successfulDictationRevision = 0

    enum AppState: Equatable {
        case idle
        case recording
        case stopping
        case transcribing
        case error(String)
    }

    enum StopRequestPurpose {
        case quickTapCancellation
        case transcription
    }

    let keyboardMonitor = KeyboardMonitor.shared
    let appSettings: AppSettingsStore
    let modelDownloader: ModelDownloader
    let audioRecorder: AudioRecorder
    let provider: any DictationProvider
    let whisperService: WhisperService
    let parakeetService: ParakeetService
    let dictionaryStore: DictionaryStore
    let weeklyWordStatsStore: WeeklyWordStatsStore
    let postProcessor: TranscriptionPostProcessor
    let vibesCoordinator: MacVibesCoordinator
    lazy var dictationChangeController = MacDictationChangeController(
        vibesCoordinator: vibesCoordinator
    )
    lazy var vibeTriggerActionController = MacVibesTriggerActionController(
        appSettings: appSettings,
        vibesCoordinator: vibesCoordinator,
        dictationChangeController: dictationChangeController
    )
    lazy var triggerController = DictationTriggerController(delegate: self)
    lazy var dictationPipeline = DictationPipeline(
        transcriptionProvider: provider,
        postProcessor: postProcessor,
        dictionaryEntriesProvider: { [weak self] in
            self?.dictionaryStore.entries ?? []
        },
        autoParagraphsEnabledProvider: { [weak self] in
            self?.appSettings.autoParagraphsEnabled ?? true
        },
        listFormattingEnabledProvider: { [weak self] in
            self?.appSettings.listFormattingEnabled ?? true
        },
        capsLockEnabledProvider: { [weak self] in
            self?.cachedCapsLockIsOn ?? false
        },
        listRenderModeProvider: {
            PasteService.shared.preferredListRenderModeForFocusedElement()
        },
        recordSpokenWords: { [weak self] text in
            self?.weeklyWordStatsStore.recordSpokenWords(from: text)
        },
        pasteText: { text in
            PasteService.shared.pasteText(text)
        },
        processOutputText: { [weak self] text in
            guard let self else { return .unchanged(text) }
            return await self.vibesCoordinator.processOutputText(text)
        }
    )
    var isLocked = false
    var cachedCapsLockIsOn = false
    var cancellables = Set<AnyCancellable>()
    let bluetoothStopSoundDelay: TimeInterval = 0.2
    let defaultStopSoundDelay: TimeInterval = 0.0
    let microphoneSilenceWarningDelay: TimeInterval = 0.5
    let noSpeechWarningMinimumCaptureDuration = AudioSilenceGatePolicy.longTrueSilenceMinimumDuration
    let dictionaryHintPromptMinimumCaptureDuration: TimeInterval = 0.45
    let dictionaryHintPromptMinimumActiveSignalRunDuration: TimeInterval = 0.35
    var stopRequestedAt: Date?
    var activeStopRequestID: UUID?
    var activeStopRequestPurpose: StopRequestPurpose?

    convenience init() {
        self.init(
            appSettings: .shared,
            modelDownloader: .shared,
            audioRecorder: AudioRecorder(),
            serviceRegistry: .shared,
            vibesCoordinator: AppServiceRegistry.shared.vibesCoordinator,
            postProcessor: TranscriptionPostProcessor()
        )
    }

    init(
        appSettings: AppSettingsStore,
        modelDownloader: ModelDownloader,
        audioRecorder: AudioRecorder,
        serviceRegistry: AppServiceRegistry,
        vibesCoordinator: MacVibesCoordinator,
        postProcessor: TranscriptionPostProcessor
    ) {
        self.appSettings = appSettings
        self.modelDownloader = modelDownloader
        self.audioRecorder = audioRecorder
        self.provider = serviceRegistry.dictationProvider
        self.whisperService = serviceRegistry.whisperService
        self.parakeetService = serviceRegistry.parakeetService
        self.dictionaryStore = serviceRegistry.dictionaryStore
        self.weeklyWordStatsStore = serviceRegistry.weeklyWordStatsStore
        self.vibesCoordinator = vibesCoordinator
        self.postProcessor = postProcessor
        cachedCapsLockIsOn = keyboardMonitor.isCapsLockOn
        setupBindings()
        provider.warmup()
    }

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}
}

extension TranscriptionManager: DictationTriggerControllerDelegate {
    var triggerAppSettings: AppSettingsStore { appSettings }
    var triggerKeyboardMonitor: KeyboardMonitor { keyboardMonitor }
    var triggerAudioRecorder: AudioRecorder { audioRecorder }
    var triggerProvider: any DictationProvider { provider }
    var triggerVibeActionController: MacVibesTriggerActionController { vibeTriggerActionController }

    var triggerState: AppState {
        get { state }
        set { state = newValue }
    }

    var triggerIsLocked: Bool {
        get { isLocked }
        set { isLocked = newValue }
    }

    var triggerActiveStopRequestID: UUID? {
        get { activeStopRequestID }
        set { activeStopRequestID = newValue }
    }

    var triggerStopRequestedAt: Date? {
        get { stopRequestedAt }
        set { stopRequestedAt = newValue }
    }

    var triggerActiveStopRequestPurpose: StopRequestPurpose? {
        get { activeStopRequestPurpose }
        set { activeStopRequestPurpose = newValue }
    }

    func triggerPlaySound(named soundName: String) {
        playSound(named: soundName)
    }

    func triggerUpdateOverlayHandsFreeVisualState() {
        updateOverlayHandsFreeVisualState()
    }

    func triggerStartRecording() {
        startRecording()
    }

    func triggerStopRecordingAndTranscribe() {
        stopRecordingAndTranscribe()
    }

    func triggerCancelQuickTapRecording() {
        cancelQuickTapRecording()
    }
}
