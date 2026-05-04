import Foundation
import KeyVoxStyleRewrite

@MainActor
final class MacVibesTriggerActionController {
    private let appSettings: AppSettingsStore
    private let vibesCoordinator: MacVibesCoordinator
    private let dictationChangeController: MacDictationChangeController
    private let quickTapMaximumDuration: TimeInterval
    private var triggerPressedAt: Date?
    private var triggerTapClassifier = MacTriggerTapClassifier()
    private var pendingSingleTapWorkItem: DispatchWorkItem?

    init(
        appSettings: AppSettingsStore,
        vibesCoordinator: MacVibesCoordinator,
        dictationChangeController: MacDictationChangeController,
        quickTapMaximumDuration: TimeInterval = 0.22
    ) {
        self.appSettings = appSettings
        self.vibesCoordinator = vibesCoordinator
        self.dictationChangeController = dictationChangeController
        self.quickTapMaximumDuration = quickTapMaximumDuration
    }

    func noteTriggerPressed(at date: Date = Date()) {
        triggerPressedAt = date
    }

    func clearTriggerPress() {
        triggerPressedAt = nil
    }

    func shouldHandleReleaseAsQuickTap(at date: Date = Date()) -> Bool {
        guard let triggerPressedAt else { return false }
        return date.timeIntervalSince(triggerPressedAt) <= quickTapMaximumDuration
    }

    func cancelPendingSingleTap() {
        pendingSingleTapWorkItem?.cancel()
        pendingSingleTapWorkItem = nil
    }

    func handleQuickTap() {
        guard vibesCoordinator.canUseVibes else {
            appSettings.selectedVibe = .none
            return
        }

        switch triggerTapClassifier.registerQuickTap(at: Date()) {
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
            OverlayManager.shared.showVibePill(title: nextStyle.displayName)
        }
    }

    private func performSingleVibeTap() async {
        pendingSingleTapWorkItem = nil
        guard vibesCoordinator.canUseVibes else {
            appSettings.selectedVibe = .none
            return
        }

        let didApply = await dictationChangeController.applyLongPressChange(
            onProcessingStart: { [weak self] in
                guard let self else { return }
                OverlayManager.shared.showVibePill(
                    title: self.vibesCoordinator.selectedVibe.displayName,
                    state: .processing,
                    duration: nil
                )
            },
            onProcessingEnd: {}
        )

        if didApply {
            OverlayManager.shared.showVibePill(
                title: dictationChangeController.currentStyle.displayName,
                state: .completed,
                duration: 0.72
            )
        } else {
            OverlayManager.shared.showVibePill(title: vibesCoordinator.selectedVibe.displayName)
        }
    }
}
