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

    @Test func warmSessionSchedulesGracePeriodBeforeOpeningContainingApp() {
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

    @Test func waitingTimeoutReturnsStateToIdle() {
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

        #expect(controller.state == .idle)
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

        ipcManager.onTranscriptionReady?("Hello world")

        #expect(receivedText == "Hello world")
        #expect(controller.state == .idle)
    }
}

private final class KeyboardDictationIPCManagerSpy: KeyboardDictationIPCManaging {
    var onRecordingStarted: (() -> Void)?
    var onTranscribingStarted: (() -> Void)?
    var onTranscriptionReady: ((String) -> Void)?
    var onNoSpeech: (() -> Void)?

    var isSessionWarmValue = false
    var hasBluetoothAudioRouteValue = false
    var hadRecentTTSPlaybackValue = false
    var currentRecordingStateValue = KeyboardState.idle
    var reconciledRecordingStateValue = KeyboardState.idle

    var registerObserversCallCount = 0
    var unregisterObserversCallCount = 0
    var sendStartCommandCallCount = 0
    var sendStopCommandCallCount = 0
    var sendCancelCommandCallCount = 0

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

    func currentRecordingState() -> KeyboardState {
        currentRecordingStateValue
    }

    func reconciledRecordingStateIfNeeded() -> KeyboardState {
        reconciledRecordingStateValue
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
