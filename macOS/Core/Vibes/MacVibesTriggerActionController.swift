import Foundation
import KeyVoxStyleRewrite

@MainActor
final class MacVibesTriggerActionController {
    private let appSettings: AppSettingsStore
    private let vibesCoordinator: MacVibesCoordinator
    private let dictationChangeController: MacDictationChangeController
    private let quickTapMaximumDuration: TimeInterval
    private var triggerPressedAt: TimeInterval?
    private var triggerTapClassifier = MacTriggerTapClassifier()
    private var pendingSingleTapWorkItem: DispatchWorkItem?

    init(
        appSettings: AppSettingsStore,
        vibesCoordinator: MacVibesCoordinator,
        dictationChangeController: MacDictationChangeController,
        quickTapMaximumDuration: TimeInterval = 0.50
    ) {
        self.appSettings = appSettings
        self.vibesCoordinator = vibesCoordinator
        self.dictationChangeController = dictationChangeController
        self.quickTapMaximumDuration = quickTapMaximumDuration
    }

    func noteTriggerPressed(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        triggerPressedAt = timestamp
    }

    func clearTriggerPress() {
        triggerPressedAt = nil
    }

    func shouldHandleReleaseAsQuickTap(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) -> Bool {
        guard let triggerPressedAt else { return false }
        return timestamp - triggerPressedAt <= quickTapMaximumDuration
    }

    func cancelPendingSingleTap() {
        pendingSingleTapWorkItem?.cancel()
        pendingSingleTapWorkItem = nil
    }

    func shouldSuppressRecordingStartForPotentialDoubleTap(
        at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime
    ) -> Bool {
        guard vibesCoordinator.canUseVibes else { return false }
        guard pendingSingleTapWorkItem != nil else { return false }
        return triggerTapClassifier.isAwaitingSecondTap(at: timestamp)
    }

    func handleQuickTap(at timestamp: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard vibesCoordinator.canUseVibes else {
            return
        }

        switch triggerTapClassifier.registerQuickTap(at: timestamp) {
        case .none:
            break
        case .scheduleSingleTap:
            cancelPendingSingleTap()
            let workItem = DispatchWorkItem { [weak self] in
                Task { @MainActor in
                    await self?.performSingleVibeTap()
                }
            }
            pendingSingleTapWorkItem = workItem
            DispatchQueue.main.asyncAfter(
                deadline: .now() + triggerTapClassifier.doubleTapInterval,
                execute: workItem
            )
        case .doubleTap:
            cancelPendingSingleTap()
            let nextStyle = vibesCoordinator.advanceSelectedVibe()
            guard nextStyle != .none || vibesCoordinator.canUseVibes else { return }
            OverlayManager.shared.showVibeCyclePill(title: nextStyle.displayName)
        }
    }

    private func performSingleVibeTap() async {
        pendingSingleTapWorkItem = nil
        guard vibesCoordinator.canUseVibes else {
            return
        }

        let didApply = await dictationChangeController.applyLongPressChange(
            onProcessingStart: { [weak self] in
                guard let self else { return }
                OverlayManager.shared.showVibePill(
                    title: self.vibesCoordinator.selectedVibe.displayName,
                    state: .processing,
                    duration: nil,
                    placement: .currentOverlayCenter
                )
            },
            onProcessingEnd: {}
        )

        if didApply {
            OverlayManager.shared.showVibePill(
                title: dictationChangeController.currentStyle.displayName,
                state: .completed,
                duration: 0.72,
                placement: .currentOverlayCenter
            )
        } else {
            OverlayManager.shared.showVibePill(
                title: vibesCoordinator.selectedVibe.displayName,
                placement: .currentOverlayCenter
            )
        }
    }
}
