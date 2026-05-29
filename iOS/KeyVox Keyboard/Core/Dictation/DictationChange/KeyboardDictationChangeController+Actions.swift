import Foundation
import KeyVoxStyleRewrite

extension KeyboardDictationChangeController {
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
        let displayedReplacementText = displayText(replacementText, for: session)

        guard textInputController.replaceUntouchedInsertion(
            session.currentText,
            with: displayedReplacementText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        ) else {
            invalidateActiveSession()
            return false
        }

        session.currentText = displayedReplacementText
        updateCapsSourceTextIfNeeded(replacementText, session: &session)
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

    func applyCapsLongPressChange() -> Bool {
        guard isApplyingChange == false else {
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

        if session.isCapsTransformApplied {
            // Restore the original baseline casing: a Caps-on dictation can have an uppercase
            // baseline, so baselineText may be uppercased even though we keep uncappedCurrentText.
            // If it already matches session.currentText, the transform is a no-op; keep the
            // uncapped source only when capsBaselineIsUppercase needs it for a future lowercase swap.
            let uncappedText = session.uncappedCurrentText ?? session.currentText
            let baselineText = session.capsBaselineIsUppercase ? uncappedText.uppercased() : uncappedText
            guard baselineText != session.currentText else {
                return false
            }

            guard textInputController.replaceUntouchedInsertion(
                session.currentText,
                with: baselineText,
                documentContextBeforeInsertion: session.documentContextBeforeInput
            ) else {
                invalidateActiveSession()
                return false
            }

            session.currentText = baselineText
            session.isCapsTransformApplied = false
            session.uncappedCurrentText = session.capsBaselineIsUppercase ? uncappedText : nil
            activeSession = session
            return true
        }

        // Apply the opposite casing from the baseline: uppercase baselines show the saved
        // uncappedText, while lowercase baselines derive transformedText by uppercasing it.
        // After replaceUntouchedInsertion succeeds, session.currentText, session.uncappedCurrentText,
        // isCapsTransformApplied, activeSession, and displaySource move to the transformed state.
        let uncappedText = session.capsBaselineIsUppercase
            ? (session.uncappedCurrentText ?? session.currentText)
            : session.currentText
        let transformedText = session.capsBaselineIsUppercase ? uncappedText : uncappedText.uppercased()
        guard transformedText != session.currentText else {
            return false
        }

        guard textInputController.replaceUntouchedInsertion(
            session.currentText,
            with: transformedText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        ) else {
            invalidateActiveSession()
            return false
        }

        session.currentText = transformedText
        session.isCapsTransformApplied = true
        session.uncappedCurrentText = uncappedText
        activeSession = session
        displaySource = .activeInsertion
        return true
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
            renderedTextForTargetState: session.renderedDeterministicVariants[KeyboardDictationRenderedVariantKey(
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

        let displayedRenderedText = displayText(renderedText, for: session)
        guard displayedRenderedText != session.currentText else {
            return false
        }

        guard textInputController.replaceUntouchedInsertion(
            session.currentText,
            with: displayedRenderedText,
            documentContextBeforeInsertion: session.documentContextBeforeInput
        ) else {
            invalidateActiveSession()
            return false
        }

        session.sourceText = replacementSourceText
        session.originalText = replacementSourceText
        session.currentText = displayedRenderedText
        updateCapsSourceTextIfNeeded(renderedText, session: &session)
        session.currentDeterministicState = targetState
        session.variants = [.none: replacementSourceText]
        session.variants[session.currentStyle] = renderedText
        activeSession = session
        return true
    }
}
