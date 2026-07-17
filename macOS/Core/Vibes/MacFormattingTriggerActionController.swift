import KeyVoxCore

@MainActor
final class MacFormattingTriggerActionController {
    private let dictationChangeController: MacDictationChangeController
    private let vibesCoordinator: MacVibesCoordinator

    init(
        dictationChangeController: MacDictationChangeController,
        vibesCoordinator: MacVibesCoordinator
    ) {
        self.dictationChangeController = dictationChangeController
        self.vibesCoordinator = vibesCoordinator
    }

    func presentProcessing(_ kind: DictationDeterministicControlKind) {
        OverlayManager.shared.showFormattingPill(
            kind: kind,
            isEnabled: false,
            state: .processing,
            duration: nil,
            placement: .currentOverlayCenter
        )
    }

    func perform(_ kind: DictationDeterministicControlKind) async {
        var didStartCompletionPresentation = false
        let outcome = await dictationChangeController.applyDeterministicChange(
            kind,
            onReplacementStart: { [weak self] targetState in
                guard let self else { return }
                didStartCompletionPresentation = true
                OverlayManager.shared.showFormattingPill(
                    kind: kind,
                    isEnabled: self.dictationChangeController.formattingEnabled(kind, in: targetState),
                    state: .completed,
                    duration: 0.72,
                    placement: .currentOverlayCenter
                )
            }
        )
        await vibesCoordinator.releasePrewarmSession(reason: "mac-formatting-shortcut")
        if outcome.didApply, didStartCompletionPresentation {
            return
        }
        let isEnabled = outcome.effectiveState.map {
            dictationChangeController.formattingEnabled(kind, in: $0)
        } ?? false

        OverlayManager.shared.showFormattingPill(
            kind: kind,
            isEnabled: isEnabled,
            state: outcome.didApply ? .completed : .normal,
            duration: outcome.didApply ? 0.72 : 0.9,
            placement: .currentOverlayCenter
        )
    }
}
