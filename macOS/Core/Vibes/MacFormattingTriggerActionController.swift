import KeyVoxCore

@MainActor
final class MacFormattingTriggerActionController {
    private let appSettings: AppSettingsStore
    private let dictationChangeController: MacDictationChangeController
    private let vibesCoordinator: MacVibesCoordinator

    init(
        appSettings: AppSettingsStore,
        dictationChangeController: MacDictationChangeController,
        vibesCoordinator: MacVibesCoordinator
    ) {
        self.appSettings = appSettings
        self.dictationChangeController = dictationChangeController
        self.vibesCoordinator = vibesCoordinator
    }

    func presentProcessing(_ kind: DictationDeterministicControlKind) {
        OverlayManager.shared.showFormattingPill(
            kind: kind,
            isEnabled: dictationChangeController.proposedFormattingEnabled(kind)
                ?? savedPreference(for: kind),
            state: .processing,
            duration: nil,
            placement: .currentOverlayCenter
        )
    }

    func perform(_ kind: DictationDeterministicControlKind) async {
        let outcome = await dictationChangeController.applyDeterministicChange(kind)
        await vibesCoordinator.releasePrewarmSession(reason: "mac-formatting-shortcut")
        let isEnabled = outcome.effectiveState.map {
            dictationChangeController.formattingEnabled(kind, in: $0)
        } ?? savedPreference(for: kind)

        OverlayManager.shared.showFormattingPill(
            kind: kind,
            isEnabled: isEnabled,
            state: outcome.didApply ? .completed : .normal,
            duration: outcome.didApply ? 0.72 : 0.9,
            placement: .currentOverlayCenter
        )
    }

    private func savedPreference(for kind: DictationDeterministicControlKind) -> Bool {
        switch kind {
        case .paragraphs:
            return appSettings.autoParagraphsEnabled
        case .lists:
            return appSettings.listFormattingEnabled
        }
    }
}
