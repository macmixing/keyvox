import Foundation
import KeyVoxCore

@MainActor
protocol DictationTriggerControllerDelegate: AnyObject {
    var triggerAppSettings: AppSettingsStore { get }
    var triggerKeyboardMonitor: KeyboardMonitor { get }
    var triggerAudioRecorder: AudioRecorder { get }
    var triggerProvider: any DictationProvider { get }
    var triggerVibeActionController: MacVibesTriggerActionController { get }
    var triggerState: TranscriptionManager.AppState { get set }
    var triggerIsLocked: Bool { get set }
    var triggerActiveStopRequestID: UUID? { get set }
    var triggerStopRequestedAt: Date? { get set }
    var triggerActiveStopRequestPurpose: TranscriptionManager.StopRequestPurpose? { get set }

    func triggerPlaySound(named soundName: String)
    func triggerUpdateOverlayHandsFreeVisualState()
    func triggerStartRecording()
    func triggerStopRecordingAndTranscribe()
    func triggerCancelQuickTapRecording()
    func triggerCancelRecordingForFormattingShortcut(completion: @escaping () -> Void)
    func triggerPresentFormattingProcessing(_ kind: DictationDeterministicControlKind)
    func triggerPerformFormatting(_ kind: DictationDeterministicControlKind) async
}

@MainActor
final class DictationTriggerController {
    weak var delegate: DictationTriggerControllerDelegate?
    private var deferredRecordingStartWorkItem: DispatchWorkItem?
    private var formattingShortcutConsumedCurrentPress = false

    init(delegate: DictationTriggerControllerDelegate) {
        self.delegate = delegate
    }

    func abortRecording() {
        guard let delegate else { return }
        guard delegate.triggerState == .recording
            || delegate.triggerState == .stopping
            || delegate.triggerState == .transcribing else { return }
        delegate.triggerActiveStopRequestID = nil
        delegate.triggerStopRequestedAt = nil
        delegate.triggerActiveStopRequestPurpose = nil

        #if DEBUG
        print("!! ESCAPE pressed: Aborting session !!")
        #endif

        delegate.triggerPlaySound(named: "Bottle")
        cancelDeferredRecordingStart()
        delegate.triggerVibeActionController.cancelPendingSingleTap()
        delegate.triggerAudioRecorder.stopRecording { _ in }
        delegate.triggerProvider.cancelTranscription()
        delegate.triggerIsLocked = false
        delegate.triggerUpdateOverlayHandsFreeVisualState()
        OverlayManager.shared.hide()
        delegate.triggerState = .idle
    }

    func handleTriggerKey(isPressed: Bool, timestamp: TimeInterval) {
        guard let delegate else { return }
        guard delegate.triggerAppSettings.hasCompletedOnboarding else { return }
        if formattingShortcutConsumedCurrentPress {
            if isPressed == false {
                formattingShortcutConsumedCurrentPress = false
                delegate.triggerVibeActionController.cancelTriggerInteraction()
                delegate.triggerUpdateOverlayHandsFreeVisualState()
            }
            return
        }
        guard delegate.triggerStopRequestedAt == nil else {
            handleTriggerDuringPendingStop(isPressed: isPressed, timestamp: timestamp)
            delegate.triggerUpdateOverlayHandsFreeVisualState()
            return
        }
        guard delegate.triggerState != .stopping else {
            #if DEBUG
            if isPressed {
                print("Trigger ignored while session is transitioning from recording to transcription.")
            }
            #endif
            delegate.triggerUpdateOverlayHandsFreeVisualState()
            return
        }

        if isPressed {
            if delegate.triggerState == .idle {
                delegate.triggerVibeActionController.noteTriggerPressed(at: timestamp)
                if delegate.triggerVibeActionController.shouldSuppressRecordingStartForPotentialDoubleTap(at: timestamp) {
                    return
                }
                if delegate.triggerVibeActionController.shouldDeferRecordingStartForVibePillCycleHandoff(
                    isVibePillVisible: OverlayManager.shared.prepareVibePillCycleHandoff()
                ) {
                    scheduleDeferredRecordingStart()
                    return
                }
                if delegate.triggerVibeActionController.shouldDeferRecordingStartForVisibleCyclePill(
                    isCyclePillVisible: OverlayManager.shared.isVibeCyclePillVisible
                ) {
                    scheduleDeferredRecordingStart()
                    return
                }
                delegate.triggerStartRecording()
            } else if delegate.triggerState == .recording && delegate.triggerIsLocked {
                delegate.triggerVibeActionController.noteTriggerPressed(at: timestamp)
                delegate.triggerIsLocked = false
                delegate.triggerStopRecordingAndTranscribe()
            } else if delegate.triggerState != .recording {
                delegate.triggerVibeActionController.clearTriggerPress()
            }
        } else {
            let didCancelDeferredRecordingStart = cancelDeferredRecordingStart()
            if delegate.triggerState == .recording {
                if delegate.triggerKeyboardMonitor.isShiftPressed {
                    delegate.triggerIsLocked = true
                    #if DEBUG
                    print("Hands-free mode LOCKED")
                    #endif
                } else if !delegate.triggerIsLocked {
                    if delegate.triggerVibeActionController.shouldHandleReleaseAsQuickTap(at: timestamp) {
                        delegate.triggerCancelQuickTapRecording()
                        delegate.triggerVibeActionController.handleQuickTap(at: timestamp)
                    } else {
                        delegate.triggerStopRecordingAndTranscribe()
                    }
                }
            }
            if delegate.triggerState == .idle,
               didCancelDeferredRecordingStart,
               delegate.triggerVibeActionController.shouldHandleReleaseAsQuickTap(at: timestamp) {
                delegate.triggerVibeActionController.handleQuickTap(at: timestamp)
            } else if delegate.triggerState == .idle,
                      delegate.triggerVibeActionController.shouldSuppressRecordingStartForPotentialDoubleTap(at: timestamp),
                      delegate.triggerVibeActionController.shouldHandleReleaseAsQuickTap(at: timestamp) {
                delegate.triggerVibeActionController.handleQuickTap(at: timestamp)
            }
            delegate.triggerVibeActionController.clearTriggerPress()
        }

        delegate.triggerUpdateOverlayHandsFreeVisualState()
    }

    func handleFormattingShortcut(_ kind: DictationDeterministicControlKind) {
        guard let delegate else { return }
        guard delegate.triggerAppSettings.hasCompletedOnboarding else { return }
        guard delegate.triggerState == .idle
            || (delegate.triggerState == .recording && delegate.triggerIsLocked == false) else {
            return
        }

        formattingShortcutConsumedCurrentPress = true
        cancelDeferredRecordingStart()
        delegate.triggerVibeActionController.cancelTriggerInteraction()
        delegate.triggerPresentFormattingProcessing(kind)

        let performFormatting = { [weak delegate] in
            guard let delegate else { return }
            Task { @MainActor in
                await delegate.triggerPerformFormatting(kind)
            }
        }

        if delegate.triggerState == .recording {
            delegate.triggerCancelRecordingForFormattingShortcut(completion: performFormatting)
        } else {
            performFormatting()
        }
    }

    @discardableResult
    func cancelDeferredRecordingStart() -> Bool {
        let hadDeferredRecordingStart = deferredRecordingStartWorkItem != nil
        deferredRecordingStartWorkItem?.cancel()
        deferredRecordingStartWorkItem = nil
        return hadDeferredRecordingStart
    }

    private func handleTriggerDuringPendingStop(isPressed: Bool, timestamp: TimeInterval) {
        guard let delegate else { return }
        guard delegate.triggerActiveStopRequestPurpose == .quickTapCancellation else {
            delegate.triggerVibeActionController.clearTriggerPress()
            return
        }

        if isPressed {
            cancelDeferredRecordingStart()
            delegate.triggerVibeActionController.noteTriggerPressed(at: timestamp)
            return
        }

        cancelDeferredRecordingStart()
        if delegate.triggerVibeActionController.shouldHandleReleaseAsQuickTap(at: timestamp) {
            delegate.triggerVibeActionController.handleQuickTap(at: timestamp)
        }
        delegate.triggerVibeActionController.clearTriggerPress()
    }

    private func scheduleDeferredRecordingStart() {
        guard let delegate else { return }
        cancelDeferredRecordingStart()
        let delay = delegate.triggerVibeActionController.quickTapDecisionDelay
        let workItem = DispatchWorkItem { [weak self] in
            guard let self, let delegate = self.delegate else { return }
            self.deferredRecordingStartWorkItem = nil
            guard delegate.triggerState == .idle,
                  delegate.triggerKeyboardMonitor.isTriggerKeyPressed else {
                return
            }
            delegate.triggerStartRecording()
        }
        deferredRecordingStartWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + delay,
            execute: workItem
        )
    }
}
