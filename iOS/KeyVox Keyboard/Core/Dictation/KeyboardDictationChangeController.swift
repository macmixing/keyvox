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
        var captureID: String?
        var rawDictationText: String?
        var baseText: String?
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

    private struct Replacement {
        let visibleText: String
        let postprocessedText: String
    }

    private let textInputController: KeyboardTextInputController
    private let artifactStore: KeyboardDictationChangeArtifactStore
    private let textTransformer = KeyboardLocalStyleRewriteTextTransformer()
    private let appSettingsStore: KeyboardAppSettingsStore
    private let deterministicFormatter = KeyboardDeterministicDictationFormatter()
    private let ratingController: KeyboardDictationRatingController

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

    var isRatingTargetStillVisible: Bool {
        guard let activeSession else { return false }
        return activeInsertionMatchesCurrentText(activeSession)
    }

    var displayedAutoParagraphsEnabled: Bool {
        guard let activeSession,
              let currentState = activeSession.currentDeterministicState,
              activeInsertionMatchesCurrentText(activeSession) else {
            return appSettingsStore.isAutoParagraphsEnabled
        }

        return deterministicFormatter.isParagraphFormattingVisiblyApplied(
            currentState: currentState,
            deterministicVariants: activeSession.deterministicVariants
        )
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
        artifactStore: KeyboardDictationChangeArtifactStore = KeyboardDictationChangeArtifactStore(),
        ratingController: KeyboardDictationRatingController
    ) {
        self.textInputController = textInputController
        self.appSettingsStore = appSettingsStore
        self.artifactStore = artifactStore
        self.ratingController = ratingController
    }

    func recordInsertedDictation(_ insertion: KeyboardTextInsertionResult) {
        displaySource = .selectedPreference

        guard let artifact = artifactStore.latestArtifact() else {
            activeSession = Session(
                sourceText: insertion.sourceText,
                originalText: insertion.insertedText,
                captureID: nil,
                rawDictationText: nil,
                baseText: nil,
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
            ratingController.deactivate()
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
            captureID: artifact.id.uuidString,
            rawDictationText: artifact.rawText,
            baseText: artifact.baseText,
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
        if selectedStyle == .none {
            ratingController.deactivate()
        } else {
            let postprocessedText = artifact.variants.first {
                $0.styleIdentifier == selectedStyle.styleIdentifier
            }?.text ?? insertion.insertedText
            ratingController.activate(PersonalDictationCaptureVariantContext(
                captureID: artifact.id.uuidString,
                styleIdentifier: selectedStyle.styleIdentifier,
                sourceText: artifact.baseText,
                visibleText: insertion.insertedText,
                rawDictationText: artifact.rawText,
                baseText: artifact.baseText,
                postprocessedOutputText: postprocessedText,
                metadata: metadata(style: selectedStyle, processingMode: nil)
            ))
        }
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
              let replacement = await replacementText(
                for: targetStyle,
                session: &session,
                onProcessingStart: onProcessingStart,
                onProcessingEnd: onProcessingEnd
              ) else {
            return false
        }

        guard textInputController.replaceUntouchedInsertion(
            session.currentText,
            with: replacement.visibleText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        ) else {
            invalidateActiveSession()
            return false
        }

        session.currentText = replacement.visibleText
        session.previousStyle = session.currentStyle
        session.currentStyle = targetStyle
        cacheRenderedText(replacement.visibleText, style: targetStyle, session: &session)
        activeSession = session
        displaySource = .activeInsertion
        activateRatingIfNeeded(
            style: targetStyle,
            session: session,
            visibleText: replacement.visibleText,
            postprocessedText: replacement.postprocessedText
        )
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
            currentSourceText: session.sourceText
        )
        guard let renderedReplacement = await renderedText(
            for: targetState,
            sourceText: replacementSourceText,
            session: &session,
            onProcessingStart: onProcessingStart,
            onProcessingEnd: onProcessingEnd
        ) else {
            return false
        }
        logChange(
            "deterministicLongPress replacementSource=\(debugText(replacementSourceText)) rendered=\(debugText(renderedReplacement.visibleText))"
        )

        if renderedReplacement.visibleText != session.currentText {
            guard textInputController.replaceUntouchedInsertion(
                session.currentText,
                with: renderedReplacement.visibleText,
                documentContextBeforeInsertion: session.documentContextBeforeInput
            ) else {
                invalidateActiveSession()
                return false
            }
        }

        session.sourceText = replacementSourceText
        session.originalText = replacementSourceText
        session.currentText = renderedReplacement.visibleText
        session.currentDeterministicState = targetState
        session.variants = [.none: replacementSourceText]
        session.variants[session.currentStyle] = renderedReplacement.visibleText
        activeSession = session
        activateRatingIfNeeded(
            style: session.currentStyle,
            session: session,
            visibleText: renderedReplacement.visibleText,
            postprocessedText: renderedReplacement.postprocessedText
        )
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
        ratingController.deactivate()
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
    ) async -> Replacement? {
        if let cachedText = session.variants[targetStyle] {
            return Replacement(visibleText: cachedText, postprocessedText: cachedText)
        }

        guard let request = StyleRewriteDictationConfiguration.request(
            for: targetStyle,
            baseText: session.sourceText
        ) else {
            return Replacement(visibleText: session.originalText, postprocessedText: session.originalText)
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
        return Replacement(visibleText: replacementText, postprocessedText: result.finalText)
    }

    private func activateRatingIfNeeded(
        style: StyleRewriteStyle,
        session: Session,
        visibleText: String,
        postprocessedText: String
    ) {
        guard style != .none else {
            ratingController.deactivate()
            return
        }

        let captureID = session.captureID ?? UUID().uuidString
        ratingController.activate(PersonalDictationCaptureVariantContext(
            captureID: captureID,
            styleIdentifier: style.styleIdentifier,
            sourceText: session.sourceText,
            visibleText: visibleText,
            rawDictationText: session.rawDictationText,
            baseText: session.baseText,
            postprocessedOutputText: postprocessedText,
            metadata: metadata(style: style, processingMode: nil)
        ))
    }

    private func metadata(
        style: StyleRewriteStyle,
        processingMode: String?
    ) -> [String: String] {
        var values: [String: String] = [
            "style": style.styleIdentifier
        ]
        if let processingMode {
            values["processing_mode"] = processingMode
        }
        return values
    }

    private func renderedText(
        for targetState: KeyboardDeterministicDictationState,
        sourceText: String,
        session: inout Session,
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> Replacement? {
        let key = RenderedVariantKey(
            deterministicState: targetState,
            style: session.currentStyle
        )
        if let cachedText = session.renderedDeterministicVariants[key] {
            return Replacement(visibleText: cachedText, postprocessedText: cachedText)
        }

        guard session.currentStyle != .none else {
            session.renderedDeterministicVariants[key] = sourceText
            return Replacement(visibleText: sourceText, postprocessedText: sourceText)
        }

        guard let request = StyleRewriteDictationConfiguration.request(
            for: session.currentStyle,
            baseText: sourceText
        ) else {
            session.renderedDeterministicVariants[key] = sourceText
            return Replacement(visibleText: sourceText, postprocessedText: sourceText)
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
        return Replacement(visibleText: replacementText, postprocessedText: result.finalText)
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
