import KeyVoxCore
import KeyVoxStyleRewrite
import XCTest
@testable import KeyVox

@MainActor
final class DictationTriggerControllerFormattingTests: XCTestCase {
    func testTriggerPressStartsRecordingSynchronously() {
        let delegate = TriggerFormattingFakeDelegate()
        let controller = DictationTriggerController(delegate: delegate)

        controller.handleTriggerKey(isPressed: true, timestamp: 1)

        XCTAssertEqual(delegate.startRecordingCount, 1)
        XCTAssertEqual(delegate.triggerState, .recording)
    }

    func testFormattingDuringRecordingDiscardsThenPerformsWithoutTranscription() async {
        let delegate = TriggerFormattingFakeDelegate()
        delegate.triggerState = .recording
        let controller = DictationTriggerController(delegate: delegate)

        controller.handleFormattingShortcut(.lists)
        await Task.yield()

        XCTAssertEqual(delegate.presentedFormattingKinds, [.lists])
        XCTAssertEqual(delegate.cancelFormattingRecordingCount, 1)
        XCTAssertEqual(delegate.performedFormattingKinds, [.lists])
        XCTAssertEqual(delegate.stopAndTranscribeCount, 0)
    }

    func testTriggerReleaseAfterFormattingCannotStopOrTranscribe() async {
        let delegate = TriggerFormattingFakeDelegate()
        delegate.triggerState = .recording
        let controller = DictationTriggerController(delegate: delegate)

        controller.handleFormattingShortcut(.paragraphs)
        await Task.yield()
        controller.handleTriggerKey(isPressed: true, timestamp: 1.1)
        controller.handleTriggerKey(isPressed: false, timestamp: 1.2)

        XCTAssertEqual(delegate.startRecordingCount, 0)
        XCTAssertEqual(delegate.stopAndTranscribeCount, 0)
        XCTAssertEqual(delegate.quickTapCancellationCount, 0)
        XCTAssertEqual(delegate.performedFormattingKinds, [.paragraphs])
    }

    func testFormattingIsIgnoredDuringLockedRecording() async {
        let delegate = TriggerFormattingFakeDelegate()
        delegate.triggerState = .recording
        delegate.triggerIsLocked = true
        let controller = DictationTriggerController(delegate: delegate)

        controller.handleFormattingShortcut(.lists)
        await Task.yield()

        XCTAssertTrue(delegate.presentedFormattingKinds.isEmpty)
        XCTAssertEqual(delegate.cancelFormattingRecordingCount, 0)
        XCTAssertTrue(delegate.performedFormattingKinds.isEmpty)
    }
}

@MainActor
private final class TriggerFormattingFakeDelegate: DictationTriggerControllerDelegate {
    let triggerAppSettings: AppSettingsStore
    let triggerKeyboardMonitor = KeyboardMonitor.shared
    let triggerAudioRecorder = AudioRecorder()
    let triggerProvider: any DictationProvider
    let triggerVibeActionController: MacVibesTriggerActionController

    var triggerState: TranscriptionManager.AppState = .idle
    var triggerIsLocked = false
    var triggerActiveStopRequestID: UUID?
    var triggerStopRequestedAt: Date?
    var triggerActiveStopRequestPurpose: TranscriptionManager.StopRequestPurpose?

    private(set) var startRecordingCount = 0
    private(set) var stopAndTranscribeCount = 0
    private(set) var quickTapCancellationCount = 0
    private(set) var cancelFormattingRecordingCount = 0
    private(set) var presentedFormattingKinds: [DictationDeterministicControlKind] = []
    private(set) var performedFormattingKinds: [DictationDeterministicControlKind] = []

    private let defaults: UserDefaults
    private let suiteName: String

    init() {
        suiteName = "DictationTriggerControllerFormattingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        triggerAppSettings = AppSettingsStore(defaults: defaults)
        triggerAppSettings.hasCompletedOnboarding = true
        triggerAppSettings.vibesTriggerKeyInteractionsEnabled = false

        let provider = TriggerFormattingFakeProvider()
        triggerProvider = provider
        let coordinator = MacVibesCoordinator(
            appSettings: triggerAppSettings,
            textTransformer: TriggerFormattingFakeTransformer(),
            isModelReady: { false }
        )
        triggerVibeActionController = MacVibesTriggerActionController(
            appSettings: triggerAppSettings,
            vibesCoordinator: coordinator,
            dictationChangeController: MacDictationChangeController(
                vibesCoordinator: coordinator
            )
        )
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func triggerPlaySound(named soundName: String) {}

    func triggerUpdateOverlayHandsFreeVisualState() {}

    func triggerStartRecording() {
        startRecordingCount += 1
        triggerState = .recording
    }

    func triggerStopRecordingAndTranscribe() {
        stopAndTranscribeCount += 1
    }

    func triggerCancelQuickTapRecording() {
        quickTapCancellationCount += 1
    }

    func triggerCancelRecordingForFormattingShortcut(completion: @escaping () -> Void) {
        cancelFormattingRecordingCount += 1
        triggerState = .idle
        completion()
    }

    func triggerPresentFormattingProcessing(_ kind: DictationDeterministicControlKind) {
        presentedFormattingKinds.append(kind)
    }

    func triggerPerformFormatting(_ kind: DictationDeterministicControlKind) async {
        performedFormattingKinds.append(kind)
    }
}

@MainActor
private final class TriggerFormattingFakeProvider: DictationProvider {
    var lastResultWasLikelyNoSpeech = false
    var isModelReady = true

    func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        completion(nil)
    }

    func cancelTranscription() {}
    func updateDictionaryHintPrompt(_ prompt: String) {}
    func warmup() {}
    func unloadModel() {}
}

@MainActor
private final class TriggerFormattingFakeTransformer: DictationTextTransforming {
    func prewarm(request: TextTransformRequest) {}

    func transform(_ request: TextTransformRequest) async -> TextTransformResult {
        TextTransformResult(
            originalText: request.baseText,
            finalText: request.baseText,
            styleIdentifier: request.styleIdentifier,
            duration: 0,
            chunkCount: 1,
            applied: false,
            chunkTimings: [],
            errors: []
        )
    }
}
