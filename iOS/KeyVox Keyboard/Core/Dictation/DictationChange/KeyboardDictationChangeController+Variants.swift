import Foundation
import KeyVoxStyleRewrite

extension KeyboardDictationChangeController {
    func targetStyle(for session: KeyboardDictationChangeSession) -> StyleRewriteStyle? {
        let selectedStyle = appSettingsStore.selectedVibe
        if selectedStyle == session.currentStyle {
            if let previousStyle = session.previousStyle {
                return previousStyle
            }

            return selectedStyle == StyleRewriteStyle.none ? nil : StyleRewriteStyle.none
        }

        return selectedStyle
    }

    func artifactBaseDeterministicState(
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

    func currentDeterministicState(
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

    func activeInsertionMatchesCurrentText(_ session: KeyboardDictationChangeSession) -> Bool {
        textInputController.currentTextMatchesUntouchedInsertion(
            session.currentText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        )
    }

    func replacementText(
        for targetStyle: StyleRewriteStyle,
        session: inout KeyboardDictationChangeSession,
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> String? {
        if let currentDeterministicState = session.currentDeterministicState,
           let cachedText = session.renderedDeterministicVariants[KeyboardDictationRenderedVariantKey(
            deterministicState: currentDeterministicState,
            style: targetStyle
           )] {
            return cachedText
        }

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
        releaseTextTransformer("keyboard-vibe-change")
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

    func renderedText(
        for targetState: KeyboardDeterministicDictationState,
        sourceText: String,
        session: inout KeyboardDictationChangeSession,
        onProcessingStart: @escaping () -> Void,
        onProcessingEnd: @escaping () -> Void
    ) async -> String? {
        let key = KeyboardDictationRenderedVariantKey(
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
        releaseTextTransformer("keyboard-deterministic-change")
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

    func cacheRenderedText(
        _ text: String,
        style: StyleRewriteStyle,
        session: inout KeyboardDictationChangeSession
    ) {
        session.variants[style] = text
        guard let currentDeterministicState = session.currentDeterministicState else {
            return
        }

        session.renderedDeterministicVariants[KeyboardDictationRenderedVariantKey(
            deterministicState: currentDeterministicState,
            style: style
        )] = text
    }

    func displayText(_ text: String, for session: KeyboardDictationChangeSession) -> String {
        capsTextIsUppercase(for: session) ? text.uppercased() : text
    }

    func updateCapsSourceTextIfNeeded(_ text: String, session: inout KeyboardDictationChangeSession) {
        guard session.capsBaselineIsUppercase || session.isCapsTransformApplied else {
            return
        }

        session.uncappedCurrentText = text
    }

    func capsTextIsUppercase(for session: KeyboardDictationChangeSession) -> Bool {
        // Baseline false/applied false = lowercase; false/true = uppercase;
        // baseline true/applied false = uppercase; true/true = lowercase.
        session.capsBaselineIsUppercase != session.isCapsTransformApplied
    }

    func initialCapsSourceText(insertedText: String, uncappedText: String) -> String? {
        guard insertedText == uncappedText.uppercased(),
              insertedText != uncappedText else {
            return nil
        }

        return uncappedText
    }

    func preparedText(
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

    func logChange(_ message: String) {
        #if DEBUG
        NSLog("[KeyboardDictationChange] %@", message)
        #endif
    }

    func debugText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}
