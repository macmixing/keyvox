import Foundation
import KeyVoxStyleRewrite

@MainActor
final class KeyboardDictationChangeController {
    let textInputController: KeyboardTextInputController
    let artifactStore: KeyboardDictationChangeArtifactStore
    let textTransformer: any DictationTextTransforming
    let releaseTextTransformer: (String) -> Void
    let appSettingsStore: KeyboardAppSettingsStore
    let deterministicFormatter = KeyboardDeterministicDictationFormatter()

    var activeSession: KeyboardDictationChangeSession?
    var isApplyingChange = false
    var displaySource: KeyboardDictationChangeDisplaySource = .selectedPreference

    var displayedVibeTitle: String {
        displayedVibeStyle.displayName
    }

    var displayedVibeStyle: StyleRewriteStyle {
        switch displaySource {
        case .selectedPreference:
            return appSettingsStore.selectedVibe
        case .activeInsertion:
            guard let activeSession, activeInsertionMatchesCurrentText(activeSession) else {
                return appSettingsStore.selectedVibe
            }

            return activeSession.currentStyle
        }
    }

    var isDisplayedVibeAppliedToCurrentInsertion: Bool {
        guard let activeSession else {
            return false
        }

        let currentDisplayedStyle = displayedVibeStyle
        return currentDisplayedStyle == activeSession.currentStyle
            && activeInsertionMatchesCurrentText(activeSession)
    }

    var displayedAutoParagraphsEnabled: Bool {
        guard let activeSession,
              let currentState = activeSession.currentDeterministicState,
              activeInsertionMatchesCurrentText(activeSession) else {
            return appSettingsStore.isAutoParagraphsEnabled
        }

        return currentState.paragraphsEnabled
    }

    var displayedListFormattingEnabled: Bool {
        guard let activeSession,
              let currentState = activeSession.currentDeterministicState,
              activeInsertionMatchesCurrentText(activeSession) else {
            return appSettingsStore.isListFormattingEnabled
        }

        return currentState.listsEnabled
    }

    var hasActiveUntouchedInsertion: Bool {
        guard let activeSession else {
            return false
        }

        return activeInsertionMatchesCurrentText(activeSession)
    }

    var displayedCapsTransformApplied: Bool {
        guard let activeSession,
              activeSession.isCapsTransformApplied,
              activeInsertionMatchesCurrentText(activeSession) else {
            return false
        }

        return true
    }

    init(
        textInputController: KeyboardTextInputController,
        appSettingsStore: KeyboardAppSettingsStore,
        artifactStore: KeyboardDictationChangeArtifactStore = KeyboardDictationChangeArtifactStore()
    ) {
        let textTransformer = KeyboardLocalStyleRewriteTextTransformer()
        self.textInputController = textInputController
        self.appSettingsStore = appSettingsStore
        self.artifactStore = artifactStore
        self.textTransformer = textTransformer
        self.releaseTextTransformer = textTransformer.releasePrewarmSession
    }

    init(
        textInputController: KeyboardTextInputController,
        appSettingsStore: KeyboardAppSettingsStore,
        artifactStore: KeyboardDictationChangeArtifactStore,
        textTransformer: any DictationTextTransforming,
        releaseTextTransformer: @escaping (String) -> Void = { _ in }
    ) {
        self.textInputController = textInputController
        self.appSettingsStore = appSettingsStore
        self.artifactStore = artifactStore
        self.textTransformer = textTransformer
        self.releaseTextTransformer = releaseTextTransformer
    }
}
