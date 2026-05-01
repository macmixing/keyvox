import Foundation
import KeyVoxStyleRewrite

@MainActor
final class KeyboardVibeChangeController {
    private struct Session {
        let sourceText: String
        let originalText: String
        let documentContextBeforeInput: String?
        let preparesAsDictationInsertion: Bool
        var currentText: String
        var currentStyle: StyleRewriteStyle
        var previousStyle: StyleRewriteStyle?
        var variants: [StyleRewriteStyle: String]
    }

    private let textInputController: KeyboardTextInputController
    private let artifactStore: KeyboardVibeChangeArtifactStore
    private let textTransformer = FoundationStyleRewriteTextTransformer()
    private let appSettingsStore: KeyboardAppSettingsStore

    private var activeSession: Session?
    private var isApplyingChange = false

    init(
        textInputController: KeyboardTextInputController,
        appSettingsStore: KeyboardAppSettingsStore,
        artifactStore: KeyboardVibeChangeArtifactStore = KeyboardVibeChangeArtifactStore()
    ) {
        self.textInputController = textInputController
        self.appSettingsStore = appSettingsStore
        self.artifactStore = artifactStore
    }

    func recordInsertedDictation(_ insertion: KeyboardTextInsertionResult) {
        guard let artifact = artifactStore.latestArtifact() else {
            activeSession = Session(
                sourceText: insertion.sourceText,
                originalText: insertion.insertedText,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true,
                currentText: insertion.insertedText,
                currentStyle: .none,
                previousStyle: nil,
                variants: [.none: insertion.insertedText]
            )
            return
        }

        let selectedStyle = artifact.selectedStyleIdentifier.flatMap(StyleRewriteStyle.init(rawValue:)) ?? .none
        let originalText = preparedText(
            artifact.baseText,
            documentContextBeforeInput: insertion.documentContextBeforeInput,
            preparesAsDictationInsertion: true
        )
        var variants: [StyleRewriteStyle: String] = [.none: originalText]
        variants[selectedStyle] = insertion.insertedText

        for variant in artifact.variants {
            guard let style = StyleRewriteStyle(rawValue: variant.styleIdentifier) else { continue }
            variants[style] = preparedText(
                variant.text,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true
            )
        }

        activeSession = Session(
            sourceText: artifact.baseText,
            originalText: originalText,
            documentContextBeforeInput: insertion.documentContextBeforeInput,
            preparesAsDictationInsertion: true,
            currentText: insertion.insertedText,
            currentStyle: selectedStyle,
            previousStyle: nil,
            variants: variants
        )
    }

    func applyLongPressChange(
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> Bool {
        guard appSettingsStore.isVibesAvailable, isApplyingChange == false else {
            return false
        }

        isApplyingChange = true
        defer { isApplyingChange = false }

        guard var session = activeSession else {
            return false
        }

        guard textInputController.currentTextMatchesUntouchedInsertion(
            session.currentText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        ) else {
            activeSession = nil
            return false
        }

        guard let targetStyle = targetStyle(for: session),
              let replacementText = await replacementText(
                for: targetStyle,
                session: &session,
                onProcessingStart: onProcessingStart,
                onProcessingEnd: onProcessingEnd
              ) else {
            return false
        }

        guard textInputController.replaceUntouchedInsertion(
            session.currentText,
            with: replacementText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        ) else {
            activeSession = nil
            return false
        }

        session.currentText = replacementText
        session.previousStyle = session.currentStyle
        session.currentStyle = targetStyle
        session.variants[targetStyle] = replacementText
        activeSession = session
        return true
    }

    private func targetStyle(for session: Session) -> StyleRewriteStyle? {
        let selectedStyle = appSettingsStore.selectedVibe
        if selectedStyle == session.currentStyle {
            if let previousStyle = session.previousStyle {
                return previousStyle
            }

            return selectedStyle == StyleRewriteStyle.none ? nil : StyleRewriteStyle.none
        }

        return selectedStyle
    }

    private func replacementText(
        for targetStyle: StyleRewriteStyle,
        session: inout Session,
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> String? {
        if let cachedText = session.variants[targetStyle] {
            return cachedText
        }

        guard let request = StyleRewriteDictationConfiguration.request(
            for: targetStyle,
            baseText: session.sourceText
        ) else {
            return session.originalText
        }

        onProcessingStart()
        defer { onProcessingEnd() }

        let result = await textTransformer.transform(request)
        textTransformer.releasePrewarmSession(reason: "keyboard-vibe-change")

        let replacementText = preparedText(
            result.finalText,
            documentContextBeforeInput: session.documentContextBeforeInput,
            preparesAsDictationInsertion: session.preparesAsDictationInsertion
        )
        guard replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        session.variants[targetStyle] = replacementText
        return replacementText
    }

    private func preparedText(
        _ text: String,
        documentContextBeforeInput: String?,
        preparesAsDictationInsertion: Bool
    ) -> String {
        guard preparesAsDictationInsertion else {
            return text
        }

        return textInputController.preparedTranscriptionText(
            text,
            documentContextBeforeInput: documentContextBeforeInput
        )
    }

}

final class KeyboardVibeChangeArtifactStore {
    private let defaults: UserDefaults?

    init(defaults: UserDefaults? = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)) {
        self.defaults = defaults
    }

    func latestArtifact() -> DictationUtteranceArtifact? {
        guard let data = defaults?.data(forKey: KeyVoxIPCBridge.Key.latestDictationArtifactData) else {
            return nil
        }

        return try? JSONDecoder().decode(DictationUtteranceArtifact.self, from: data)
    }
}
