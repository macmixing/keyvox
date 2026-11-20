import Foundation
import Testing
@testable import KeyVox_iOS

struct KeyboardDictationControllerTests {
    @Test func coldSessionOpensContainingAppImmediately() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()

        #expect(controller.state == .waitingForApp)
        #expect(ipcManager.sendStartCommandCallCount == 0)
        #expect(appLauncher.openedURLs == [URL(string: "keyvoxios://record/start")!])
        #expect(scheduler.scheduledDelays == [5.0])
    }

    @Test func warmSessionStartsRecordingImmediatelyBeforeGraceFallback() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = true
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()

        #expect(controller.state == .recording)

        scheduler.runScheduledAction(after: 0.5)

        #expect(controller.state == .waitingForApp)
        #expect(ipcManager.sendStartCommandCallCount == 1)
        #expect(appLauncher.openedURLs == [URL(string: "keyvoxios://record/start")!])
        #expect(scheduler.scheduledDelays == [5.0, 0.5])
    }

    @Test func recordingStartCancelsGracePeriodFallbackLaunch() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = true
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()
        ipcManager.onRecordingStarted?()
        scheduler.runScheduledAction(after: 0.5)

        #expect(controller.state == .recording)
        #expect(appLauncher.openedURLs.isEmpty)
    }

    @Test func warmSessionGracePeriodAdoptsRecordingStateWhenStartNotificationIsMissed() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = true
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()

        #expect(controller.state == .recording)

        ipcManager.currentRecordingStateValue = .recording
        scheduler.runScheduledAction(after: 0.5)

        #expect(controller.state == .recording)
        #expect(appLauncher.openedURLs.isEmpty)
    }

    @Test func waitingTimeoutShowsFailureBeforeReturningToIdle() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()
        scheduler.runScheduledAction(after: 5.0)

        #expect(controller.state == .dictationStartFailed)

        scheduler.runScheduledAction(after: 2.0)

        #expect(controller.state == .idle)
    }

    @Test func explicitStartFailureShowsFailureAndClearsSharedResultAfterDisplay() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = true
        ipcManager.currentRecordingStateValue = .dictationStartFailed
        let scheduler = KeyboardActionSchedulerSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: { _ in },
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()
        ipcManager.onRecordingStartFailed?()

        #expect(controller.state == .dictationStartFailed)
        #expect(ipcManager.clearRecordingStartFailureCallCount == 1)

        ipcManager.reconciledRecordingStateValue = .idle
        scheduler.runScheduledAction(after: 2.0)

        #expect(controller.state == .idle)
        #expect(ipcManager.clearRecordingStartFailureCallCount == 2)
    }

    @Test func sharedStartFailureIsPresentedAfterContainingAppHandoff() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        let scheduler = KeyboardActionSchedulerSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: { _ in },
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()
        ipcManager.reconciledRecordingStateValue = .dictationStartFailed
        controller.syncStateFromSharedState()

        #expect(controller.state == .dictationStartFailed)
        #expect(ipcManager.clearRecordingStartFailureCallCount == 1)
    }

    @Test func tappingMicWhileRecordingStopsAndTransitionsToTranscribing() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.reconciledRecordingStateValue = .recording
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()

        #expect(controller.state == .transcribing)
        #expect(ipcManager.sendStopCommandCallCount == 1)
        #expect(appLauncher.openedURLs.isEmpty)
    }

    @Test func transcribingReconciliationInsertsTextWhenReadyNotificationIsMissed() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.reconciledRecordingStateValue = .recording
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )
        var receivedText: String?

        controller.onTranscriptionReady = { text in
            receivedText = text
        }

        controller.handleMicTap()
        ipcManager.reconciledRecordingStateValue = .idle
        ipcManager.currentTranscriptionValue = "Edited message text"
        scheduler.runScheduledAction(after: 0.5)

        #expect(receivedText == "Edited message text")
        #expect(controller.state == .idle)
    }

    @Test func transcribingReconciliationRetriesStopWhileSharedStateIsStillTranscribing() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.reconciledRecordingStateValue = .recording
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )

        controller.handleMicTap()
        ipcManager.reconciledRecordingStateValue = .transcribing
        scheduler.runScheduledAction(after: 0.5)

        #expect(controller.state == .transcribing)
        #expect(ipcManager.sendStopCommandCallCount == 2)
    }

    @Test func transcribingReconciliationKeepsWaitingAfterStopRetryLimit() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.reconciledRecordingStateValue = .recording
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start"),
            maxTranscriptionReconciliationRetries: 1
        )

        controller.handleMicTap()
        ipcManager.reconciledRecordingStateValue = .transcribing
        scheduler.runScheduledAction(after: 0.5)
        scheduler.runScheduledAction(after: 0.5)
        scheduler.runScheduledAction(after: 0.5)

        #expect(controller.state == .transcribing)
        #expect(ipcManager.sendStopCommandCallCount == 2)
    }

    @Test func transcriptionReadyForwardsTextAndResetsState() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )
        var receivedText: String?

        controller.onTranscriptionReady = { text in
            receivedText = text
        }

        ipcManager.onTranscribingStarted?()
        ipcManager.onTranscriptionReady?("Hello world")

        #expect(receivedText == "Hello world")
        #expect(controller.state == .idle)
    }

    @Test func transcriptionReadyAfterReconciliationDoesNotForwardDuplicateText() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.reconciledRecordingStateValue = .idle
        ipcManager.currentTranscriptionValue = "Hello world"
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: URL(string: "keyvoxios://record/start")
        )
        var receivedTexts: [String] = []

        controller.onTranscriptionReady = { text in
            receivedTexts.append(text)
        }

        ipcManager.onTranscribingStarted?()
        scheduler.runScheduledAction(after: 0.5)
        ipcManager.onTranscriptionReady?("Hello world")

        #expect(receivedTexts == ["Hello world"])
        #expect(controller.state == .idle)
    }

    @Test func coldSessionDictatesInKeyboardWithoutOpeningContainingApp() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: Self.startRecordingURL
        )
        let transcript = UUID().uuidString
        var receivedTexts: [String] = []
        controller.onTranscriptionReady = { text in
            receivedTexts.append(text)
        }

        controller.handleMicTap()
        controller.handleMicTap()

        #expect(controller.state == .startingDictation)
        #expect(standaloneDictation.startCallCount == 1)

        standaloneDictation.onRecordingStarted?()

        #expect(controller.state == .recording)

        controller.handleMicTap()

        #expect(controller.state == .transcribing)
        #expect(standaloneDictation.stopCallCount == 1)

        standaloneDictation.onTranscriptionReady?(transcript)

        #expect(controller.state == .idle)
        #expect(receivedTexts == [transcript])
        #expect(appLauncher.openedURLs.isEmpty)
        #expect(ipcManager.sendStartCommandCallCount == 0)
        #expect(ipcManager.sendStopCommandCallCount == 0)
    }

    @Test func coldSessionOpensContainingAppWhenKeyboardDictationIsUnavailable() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        standaloneDictation.isAvailable = false
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()

        #expect(controller.state == .waitingForApp)
        #expect(standaloneDictation.startCallCount == 0)
        #expect(appLauncher.openedURLs == [Self.startRecordingURL])
    }

    @Test func warmSessionDoesNotDictateInKeyboard() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = true
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: { _ in },
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()

        #expect(controller.state == .recording)
        #expect(ipcManager.sendStartCommandCallCount == 1)
        #expect(standaloneDictation.startCallCount == 0)
    }

    @Test(arguments: [false, true])
    func keyboardDictationFailureFallsBackToContainingApp(failsAfterRecordingStarted: Bool) {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()
        if failsAfterRecordingStarted {
            standaloneDictation.onRecordingStarted?()
            controller.handleMicTap()
        }
        standaloneDictation.onFailure?()

        #expect(controller.state == .waitingForApp)
        #expect(appLauncher.openedURLs == [Self.startRecordingURL])
    }

    @Test func keyboardDictationThatNeverStartsShowsFailureWithoutOpeningContainingApp() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()
        scheduler.runScheduledAction(after: 5.0)

        #expect(controller.state == .dictationStartFailed)
        #expect(standaloneDictation.cancelCallCount == 1)
        #expect(appLauncher.openedURLs.isEmpty)

        scheduler.runScheduledAction(after: 2.0)

        #expect(controller.state == .idle)
    }

    @Test func keyboardDictationStaysInControlWhileSharedStateIsIdle() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        ipcManager.reconciledRecordingStateValue = .idle
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: { _ in },
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()
        standaloneDictation.onRecordingStarted?()
        controller.syncStateFromSharedState()

        #expect(controller.state == .recording)
    }

    @Test func cancelTapEndsKeyboardDictationWithoutCommandingContainingApp() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: { _ in },
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()
        standaloneDictation.onRecordingStarted?()
        controller.handleCancelTap()

        #expect(controller.state == .idle)
        #expect(standaloneDictation.cancelCallCount == 1)
        #expect(ipcManager.sendCancelCommandCallCount == 0)
    }

    @Test(arguments: [false, true])
    func hostLeavingTheFrontEndsOnlyAKeyboardDictationStillRecording(isTranscribing: Bool) {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: { _ in },
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()
        standaloneDictation.onRecordingStarted?()
        if isTranscribing {
            controller.handleMicTap()
        }
        controller.cancelStandaloneRecording()

        #expect(controller.state == (isTranscribing ? .transcribing : .idle))
        #expect(standaloneDictation.cancelCallCount == (isTranscribing ? 0 : 1))
    }

    @Test func keyboardRecordingThatCannotStartShowsFailureWithoutOpeningContainingApp() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let scheduler = KeyboardActionSchedulerSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: scheduler.schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()
        standaloneDictation.onRecordingStartFailed?()

        #expect(controller.state == .dictationStartFailed)
        #expect(appLauncher.openedURLs.isEmpty)

        scheduler.runScheduledAction(after: 2.0)

        #expect(controller.state == .idle)

        controller.handleMicTap()

        #expect(standaloneDictation.startCallCount == 2)
    }

    @Test func keyboardRecordingCutOffIsTranscribedAndInserted() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: Self.startRecordingURL
        )
        let transcript = UUID().uuidString
        var receivedTexts: [String] = []
        controller.onTranscriptionReady = { text in
            receivedTexts.append(text)
        }

        controller.handleMicTap()
        standaloneDictation.onRecordingStarted?()
        standaloneDictation.onTranscribingStarted?()

        #expect(controller.state == .transcribing)
        #expect(standaloneDictation.stopCallCount == 0)

        standaloneDictation.onTranscriptionReady?(transcript)

        #expect(controller.state == .idle)
        #expect(receivedTexts == [transcript])
        #expect(appLauncher.openedURLs.isEmpty)
    }

    @Test func keyboardDictationWithoutSpeechReturnsToIdle() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let appLauncher = KeyboardContainingAppLauncherSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: appLauncher.open,
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()
        standaloneDictation.onRecordingStarted?()
        controller.handleMicTap()
        standaloneDictation.onNoSpeech?()

        #expect(controller.state == .idle)
        #expect(appLauncher.openedURLs.isEmpty)
    }

    @Test func leavingTheKeyboardEndsKeyboardDictation() {
        let ipcManager = KeyboardDictationIPCManagerSpy()
        ipcManager.isSessionWarmValue = false
        let standaloneDictation = KeyboardStandaloneDictationSpy()
        let controller = KeyboardDictationController(
            ipcManager: ipcManager,
            standaloneDictation: standaloneDictation,
            scheduleAction: KeyboardActionSchedulerSpy().schedule,
            openContainingApp: { _ in },
            startRecordingURL: Self.startRecordingURL
        )

        controller.handleMicTap()
        standaloneDictation.onRecordingStarted?()
        controller.unregisterObservers()
        controller.syncStateFromSharedState()

        #expect(controller.state == .idle)
        #expect(standaloneDictation.deactivateCallCount == 1)
    }

    private static let startRecordingURL = URL(string: "keyvoxios://record/start")!
}

private final class KeyboardStandaloneDictationSpy: KeyboardStandaloneDictating {
    var onRecordingStarted: (() -> Void)?
    var onRecordingStartFailed: (() -> Void)?
    var onTranscribingStarted: (() -> Void)?
    var onTranscriptionReady: ((String) -> Void)?
    var onNoSpeech: (() -> Void)?
    var onFailure: (() -> Void)?

    var isAvailable = true

    var startCallCount = 0
    var stopCallCount = 0
    var cancelCallCount = 0
    var deactivateCallCount = 0

    func start() {
        startCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }

    func cancel() {
        cancelCallCount += 1
    }

    func deactivate() {
        deactivateCallCount += 1
    }
}

private final class KeyboardDictationIPCManagerSpy: KeyboardDictationIPCManaging {
    var onRecordingStarted: (() -> Void)?
    var onRecordingStartFailed: (() -> Void)?
    var onTranscribingStarted: (() -> Void)?
    var onTranscriptionReady: ((String) -> Void)?
    var onNoSpeech: (() -> Void)?

    var isSessionWarmValue = false
    var hasBluetoothAudioRouteValue = false
    var hadRecentTTSPlaybackValue = false
    var currentRecordingStateValue = KeyboardState.idle
    var reconciledRecordingStateValue = KeyboardState.idle
    var currentTranscriptionValue: String?

    var registerObserversCallCount = 0
    var unregisterObserversCallCount = 0
    var sendStartCommandCallCount = 0
    var sendStopCommandCallCount = 0
    var sendCancelCommandCallCount = 0
    var clearRecordingStartFailureCallCount = 0

    func registerObservers() {
        registerObserversCallCount += 1
    }

    func unregisterObservers() {
        unregisterObserversCallCount += 1
    }

    func sendStartCommand() {
        sendStartCommandCallCount += 1
    }

    func sendStopCommand() {
        sendStopCommandCallCount += 1
    }

    func sendCancelCommand() {
        sendCancelCommandCallCount += 1
    }

    func clearRecordingStartFailure() {
        clearRecordingStartFailureCallCount += 1
    }

    func currentRecordingState() -> KeyboardState {
        currentRecordingStateValue
    }

    func reconciledRecordingStateIfNeeded() -> KeyboardState {
        reconciledRecordingStateValue
    }

    func currentTranscription() -> String? {
        currentTranscriptionValue
    }

    func isSessionWarm() -> Bool {
        isSessionWarmValue
    }

    func hasBluetoothAudioRoute() -> Bool {
        hasBluetoothAudioRouteValue
    }

    func hadRecentTTSPlayback() -> Bool {
        hadRecentTTSPlaybackValue
    }
}

private final class KeyboardActionSchedulerSpy {
    private final class ScheduledActionToken {
        var isCancelled = false

        func cancel() {
            isCancelled = true
        }
    }

    private struct Entry {
        let delay: TimeInterval
        let action: () -> Void
        let token: ScheduledActionToken
    }

    private var entries: [Entry] = []
    private var delayHistory: [TimeInterval] = []

    var scheduledDelays: [TimeInterval] {
        delayHistory
    }

    func schedule(after delay: TimeInterval, action: @escaping () -> Void) -> KeyboardScheduledAction {
        let token = ScheduledActionToken()
        delayHistory.append(delay)
        entries.append(Entry(delay: delay, action: action, token: token))
        return KeyboardScheduledAction(cancel: {
            token.cancel()
        })
    }

    func runScheduledAction(after delay: TimeInterval) {
        guard let index = entries.firstIndex(where: { $0.delay == delay }) else { return }
        let entry = entries.remove(at: index)
        guard entry.token.isCancelled == false else { return }
        entry.action()
    }
}

private final class KeyboardContainingAppLauncherSpy {
    var openedURLs: [URL] = []

    func open(_ url: URL?) {
        guard let url else { return }
        openedURLs.append(url)
    }
}
