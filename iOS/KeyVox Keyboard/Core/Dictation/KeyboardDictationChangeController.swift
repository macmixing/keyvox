import Foundation
import KeyVoxStyleRewrite

@MainActor
final class KeyboardDictationChangeController {
    enum DeterministicControlKind {
        case paragraphs
        case lists
    }

    private struct DeterministicState: Hashable {
        let paragraphsEnabled: Bool
        let listsEnabled: Bool
    }

    private struct RenderedVariantKey: Hashable {
        let deterministicState: DeterministicState
        let style: StyleRewriteStyle
    }

    private enum DisplaySource {
        case selectedPreference
        case activeInsertion
    }

    private struct Session {
        var sourceText: String
        var originalText: String
        let documentContextBeforeInput: String?
        let preparesAsDictationInsertion: Bool
        var currentText: String
        var currentStyle: StyleRewriteStyle
        var previousStyle: StyleRewriteStyle?
        var variants: [StyleRewriteStyle: String]
        var currentDeterministicState: DeterministicState?
        var deterministicVariants: [DeterministicState: String]
        var renderedDeterministicVariants: [RenderedVariantKey: String]
    }

    private let textInputController: KeyboardTextInputController
    private let artifactStore: KeyboardDictationChangeArtifactStore
    private let textTransformer = KeyboardLocalStyleRewriteTextTransformer()
    private let appSettingsStore: KeyboardAppSettingsStore

    private var activeSession: Session?
    private var isApplyingChange = false
    private var displaySource: DisplaySource = .selectedPreference

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

    init(
        textInputController: KeyboardTextInputController,
        appSettingsStore: KeyboardAppSettingsStore,
        artifactStore: KeyboardDictationChangeArtifactStore = KeyboardDictationChangeArtifactStore()
    ) {
        self.textInputController = textInputController
        self.appSettingsStore = appSettingsStore
        self.artifactStore = artifactStore
    }

    func recordInsertedDictation(_ insertion: KeyboardTextInsertionResult) {
        displaySource = .selectedPreference

        guard let artifact = artifactStore.latestArtifact() else {
            activeSession = Session(
                sourceText: insertion.sourceText,
                originalText: insertion.insertedText,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true,
                currentText: insertion.insertedText,
                currentStyle: .none,
                previousStyle: nil,
                variants: [.none: insertion.insertedText],
                currentDeterministicState: nil,
                deterministicVariants: [:],
                renderedDeterministicVariants: [:]
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

        var deterministicVariants: [DeterministicState: String] = [:]
        for variant in artifact.deterministicVariants {
            let state = DeterministicState(
                paragraphsEnabled: variant.paragraphsEnabled,
                listsEnabled: variant.listsEnabled
            )
            deterministicVariants[state] = preparedText(
                variant.text,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true
            )
        }
        let currentDeterministicState = deterministicVariants.first {
            $0.value == originalText
        }?.key
        var renderedDeterministicVariants: [RenderedVariantKey: String] = [:]
        if let currentDeterministicState {
            renderedDeterministicVariants[RenderedVariantKey(
                deterministicState: currentDeterministicState,
                style: .none
            )] = originalText
            renderedDeterministicVariants[RenderedVariantKey(
                deterministicState: currentDeterministicState,
                style: selectedStyle
            )] = insertion.insertedText
        }

        activeSession = Session(
            sourceText: originalText,
            originalText: originalText,
            documentContextBeforeInput: insertion.documentContextBeforeInput,
            preparesAsDictationInsertion: true,
            currentText: insertion.insertedText,
            currentStyle: selectedStyle,
            previousStyle: nil,
            variants: variants,
            currentDeterministicState: currentDeterministicState,
            deterministicVariants: deterministicVariants,
            renderedDeterministicVariants: renderedDeterministicVariants
        )
    }

    func applyLongPressChange(
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> Bool {
        guard appSettingsStore.canUseVibes, isApplyingChange == false else {
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
            invalidateActiveSession()
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
            invalidateActiveSession()
            return false
        }

        session.currentText = replacementText
        session.previousStyle = session.currentStyle
        session.currentStyle = targetStyle
        cacheRenderedText(replacementText, style: targetStyle, session: &session)
        activeSession = session
        displaySource = .activeInsertion
        return true
    }

    func showSelectedVibePreference() {
        displaySource = .selectedPreference
    }

    func applyDeterministicLongPressChange(
        _ kind: DeterministicControlKind,
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> Bool {
        guard isApplyingChange == false else {
            return false
        }

        isApplyingChange = true
        defer { isApplyingChange = false }

        guard var session = activeSession,
              let currentState = session.currentDeterministicState else {
            return false
        }

        guard textInputController.currentTextMatchesUntouchedInsertion(
            session.currentText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        ) else {
            invalidateActiveSession()
            return false
        }

        if appSettingsStore.canUseVibes == false {
            session.currentStyle = .none
        }

        let targetState = targetDeterministicState(from: currentState, kind: kind)
        guard let replacementText = session.deterministicVariants[targetState],
              let renderedText = await renderedText(
                for: targetState,
                sourceText: replacementText,
                session: &session,
                onProcessingStart: onProcessingStart,
                onProcessingEnd: onProcessingEnd
              ) else {
            return false
        }

        if renderedText != session.currentText {
            guard textInputController.replaceUntouchedInsertion(
                session.currentText,
                with: renderedText,
                documentContextBeforeInsertion: session.documentContextBeforeInput
            ) else {
                invalidateActiveSession()
                return false
            }
        }

        session.sourceText = replacementText
        session.originalText = replacementText
        session.currentText = renderedText
        session.currentDeterministicState = targetState
        session.variants = [.none: replacementText]
        session.variants[session.currentStyle] = renderedText
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

    private func invalidateActiveSession() {
        activeSession = nil
    }

    private func activeInsertionMatchesCurrentText(_ session: Session) -> Bool {
        textInputController.currentTextMatchesUntouchedInsertion(
            session.currentText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        )
    }

    private func targetDeterministicState(
        from state: DeterministicState,
        kind: DeterministicControlKind
    ) -> DeterministicState {
        switch kind {
        case .paragraphs:
            return DeterministicState(
                paragraphsEnabled: !state.paragraphsEnabled,
                listsEnabled: state.listsEnabled
            )
        case .lists:
            return DeterministicState(
                paragraphsEnabled: state.paragraphsEnabled,
                listsEnabled: !state.listsEnabled
            )
        }
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

        cacheRenderedText(replacementText, style: targetStyle, session: &session)
        return replacementText
    }

    private func renderedText(
        for targetState: DeterministicState,
        sourceText: String,
        session: inout Session,
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> String? {
        let key = RenderedVariantKey(
            deterministicState: targetState,
            style: session.currentStyle
        )
        if let cachedText = session.renderedDeterministicVariants[key] {
            return cachedText
        }

        guard session.currentStyle != .none else {
            session.renderedDeterministicVariants[key] = sourceText
            return sourceText
        }

        guard let request = StyleRewriteDictationConfiguration.request(
            for: session.currentStyle,
            baseText: sourceText
        ) else {
            session.renderedDeterministicVariants[key] = sourceText
            return sourceText
        }

        onProcessingStart()
        defer { onProcessingEnd() }

        let result = await textTransformer.transform(request)
        textTransformer.releasePrewarmSession(reason: "keyboard-deterministic-change")

        let replacementText = textAdjustedForDeterministicState(
            preparedText(
                result.finalText,
                documentContextBeforeInput: session.documentContextBeforeInput,
                preparesAsDictationInsertion: session.preparesAsDictationInsertion
            ),
            state: targetState
        )
        guard replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        session.renderedDeterministicVariants[key] = replacementText
        return replacementText
    }

    private func cacheRenderedText(
        _ text: String,
        style: StyleRewriteStyle,
        session: inout Session
    ) {
        session.variants[style] = text
        guard let currentDeterministicState = session.currentDeterministicState else {
            return
        }

        session.renderedDeterministicVariants[RenderedVariantKey(
            deterministicState: currentDeterministicState,
            style: style
        )] = text
    }

    private func textAdjustedForDeterministicState(
        _ text: String,
        state: DeterministicState
    ) -> String {
        guard state.paragraphsEnabled == false else {
            return text
        }

        return text
            .replacingOccurrences(of: "\\s*\\n+\\s*", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "[ \\t]+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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

final class KeyboardDictationChangeArtifactStore {
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
