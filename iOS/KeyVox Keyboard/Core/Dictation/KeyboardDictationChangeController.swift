import Foundation
import KeyVoxStyleRewrite

@MainActor
final class KeyboardDictationChangeController {
    private struct RenderedVariantKey: Hashable {
        let deterministicState: KeyboardDeterministicDictationState
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
        var currentDeterministicState: KeyboardDeterministicDictationState?
        var deterministicVariants: [KeyboardDeterministicDictationState: String]
        var renderedDeterministicVariants: [RenderedVariantKey: String]
    }

    private let textInputController: KeyboardTextInputController
    private let artifactStore: KeyboardDictationChangeArtifactStore
    private let textTransformer = KeyboardLocalStyleRewriteTextTransformer()
    private let appSettingsStore: KeyboardAppSettingsStore
    private let deterministicFormatter = KeyboardDeterministicDictationFormatter()

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

        var deterministicVariants: [KeyboardDeterministicDictationState: String] = [:]
        for variant in artifact.deterministicVariants {
            let state = KeyboardDeterministicDictationState(
                paragraphsEnabled: variant.paragraphsEnabled,
                listsEnabled: variant.listsEnabled
            )
            deterministicVariants[state] = preparedText(
                variant.text,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true
            )
        }
        let currentDeterministicState = artifactBaseDeterministicState(
            from: artifact,
            deterministicVariants: deterministicVariants
        ) ?? currentDeterministicState(
            matching: originalText,
            in: deterministicVariants
        )
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
        _ kind: KeyboardDeterministicControlKind,
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

        let targetState = deterministicFormatter.targetState(from: currentState, kind: kind)
        logChange(
            "deterministicLongPress kind=\(kind.debugLabel) currentStyle=\(session.currentStyle.styleIdentifier) currentState=\(currentState.debugDescription) targetState=\(targetState.debugDescription) currentText=\(debugText(session.currentText))"
        )
        guard let deterministicText = session.deterministicVariants[targetState] else {
            return false
        }

        let replacementSourceText = deterministicFormatter.sourceText(
            for: targetState,
            deterministicText: deterministicText,
            currentState: currentState,
            currentSourceText: session.sourceText,
            renderedTextForTargetState: session.renderedDeterministicVariants[RenderedVariantKey(
                deterministicState: targetState,
                style: .none
            )]
        )
        guard replacementSourceText != session.sourceText else {
            return false
        }

        guard let renderedText = await renderedText(
            for: targetState,
            sourceText: replacementSourceText,
            session: &session,
            onProcessingStart: onProcessingStart,
            onProcessingEnd: onProcessingEnd
        ) else {
            return false
        }
        logChange(
            "deterministicLongPress replacementSource=\(debugText(replacementSourceText)) rendered=\(debugText(renderedText))"
        )

        guard renderedText != session.currentText else {
            return false
        }

        guard textInputController.replaceUntouchedInsertion(
            session.currentText,
            with: renderedText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        ) else {
            invalidateActiveSession()
            return false
        }

        session.sourceText = replacementSourceText
        session.originalText = replacementSourceText
        session.currentText = renderedText
        session.currentDeterministicState = targetState
        session.variants = [.none: replacementSourceText]
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

    private func artifactBaseDeterministicState(
        from artifact: DictationUtteranceArtifact,
        deterministicVariants: [KeyboardDeterministicDictationState: String]
    ) -> KeyboardDeterministicDictationState? {
        guard let paragraphsEnabled = artifact.baseParagraphsEnabled,
              let listsEnabled = artifact.baseListsEnabled else {
            return nil
        }

        let state = KeyboardDeterministicDictationState(
            paragraphsEnabled: paragraphsEnabled,
            listsEnabled: listsEnabled
        )
        return deterministicVariants[state] == nil ? nil : state
    }

    private func currentDeterministicState(
        matching text: String,
        in deterministicVariants: [KeyboardDeterministicDictationState: String]
    ) -> KeyboardDeterministicDictationState? {
        let matchingStates = deterministicVariants
            .filter { $0.value == text }
            .map { $0.key }
        guard !matchingStates.isEmpty else {
            return nil
        }

        let preferredState = KeyboardDeterministicDictationState(
            paragraphsEnabled: appSettingsStore.isAutoParagraphsEnabled,
            listsEnabled: appSettingsStore.isListFormattingEnabled
        )
        return matchingStates.first { $0 == preferredState } ?? matchingStates.min {
            if $0.paragraphsEnabled != $1.paragraphsEnabled {
                return $0.paragraphsEnabled == false
            }

            return $0.listsEnabled == false && $1.listsEnabled
        }
    }

    private func activeInsertionMatchesCurrentText(_ session: Session) -> Bool {
        textInputController.currentTextMatchesUntouchedInsertion(
            session.currentText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        )
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
        logChange(
            "vibeApply style=\(targetStyle.styleIdentifier) applied=\(result.applied) mode=\(result.processingMode ?? "nil") final=\(debugText(result.finalText))"
        )

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
        for targetState: KeyboardDeterministicDictationState,
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
        logChange(
            "renderedText result style=\(session.currentStyle.styleIdentifier) applied=\(result.applied) mode=\(result.processingMode ?? "nil") final=\(debugText(result.finalText))"
        )

        let replacementText = deterministicFormatter.textAdjustedForDeterministicState(
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

    private func logChange(_ message: String) {
        #if DEBUG
        NSLog("[KeyboardDictationChange] %@", message)
        #endif
    }

    private func debugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
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
