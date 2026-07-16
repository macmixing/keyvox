import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

extension MacDictationChangeController {
    func applyDeterministicChange(
        _ kind: DictationDeterministicControlKind
    ) async -> MacFormattingChangeOutcome {
        guard isApplyingChange == false else {
            return MacFormattingChangeOutcome(
                didApply: false,
                effectiveState: activeSession?.currentDeterministicState
            )
        }

        isApplyingChange = true
        defer { isApplyingChange = false }

        guard var session = activeSession else {
            return MacFormattingChangeOutcome(didApply: false, effectiveState: nil)
        }

        guard await pasteService.currentTextMatchesUntouchedInsertion(session.currentText) else {
            activeSession = nil
            return MacFormattingChangeOutcome(
                didApply: false,
                effectiveState: session.currentDeterministicState
            )
        }

        let currentState = session.currentDeterministicState
        guard let target = deterministicChangeTarget(for: kind, in: session) else {
            return MacFormattingChangeOutcome(didApply: false, effectiveState: currentState)
        }
        let targetState = target.state
        let replacementSourceText = target.sourceText
        if replacementSourceText == session.sourceText {
            let effectiveState = deterministicStateByDisabling(kind, in: currentState)
            session.currentDeterministicState = effectiveState
            activeSession = session
            return MacFormattingChangeOutcome(
                didApply: false,
                effectiveState: effectiveState
            )
        }

        guard let renderedText = await renderedText(
            for: targetState,
            sourceText: replacementSourceText,
            session: &session
        ) else {
            return MacFormattingChangeOutcome(didApply: false, effectiveState: currentState)
        }

        let displayedText = displayText(renderedText, for: session)
        let requiresReplacement = displayedText != session.currentText
        if requiresReplacement {
            guard await pasteService.replaceUntouchedInsertion(
                session.currentText,
                with: displayedText
            ) else {
                activeSession = nil
                return MacFormattingChangeOutcome(
                    didApply: false,
                    effectiveState: session.currentDeterministicState
                )
            }
        } else if await pasteService.currentTextMatchesUntouchedInsertion(session.currentText) == false {
            activeSession = nil
            return MacFormattingChangeOutcome(
                didApply: false,
                effectiveState: session.currentDeterministicState
            )
        }

        session.sourceText = replacementSourceText
        session.originalText = replacementSourceText
        session.currentText = displayedText
        session.currentDeterministicState = targetState
        session.variants = [.none: replacementSourceText]
        session.variants[session.currentStyle] = renderedText
        session.renderedDeterministicVariants[MacDictationRenderedVariantKey(
            deterministicState: targetState,
            style: .none
        )] = replacementSourceText
        session.renderedDeterministicVariants[MacDictationRenderedVariantKey(
            deterministicState: targetState,
            style: session.currentStyle
        )] = renderedText
        activeSession = session

        return MacFormattingChangeOutcome(
            didApply: requiresReplacement,
            effectiveState: targetState
        )
    }

    func deterministicChangeTarget(
        for kind: DictationDeterministicControlKind,
        in session: MacDictationChangeSession
    ) -> (state: DictationDeterministicState, sourceText: String)? {
        let currentState = session.currentDeterministicState
        let targetState = deterministicVariantResolver.targetState(from: currentState, kind: kind)
        guard let deterministicText = session.deterministicVariants[targetState] else {
            return nil
        }

        let sourceText = deterministicVariantResolver.sourceText(
            for: targetState,
            deterministicText: deterministicText,
            currentState: currentState,
            currentSourceText: session.sourceText,
            renderedTextForTargetState: session.renderedDeterministicVariants[MacDictationRenderedVariantKey(
                deterministicState: targetState,
                style: .none
            )]
        )
        return (targetState, sourceText)
    }

    func deterministicStateByDisabling(
        _ kind: DictationDeterministicControlKind,
        in state: DictationDeterministicState
    ) -> DictationDeterministicState {
        switch kind {
        case .paragraphs:
            return DictationDeterministicState(
                paragraphsEnabled: false,
                listsEnabled: state.listsEnabled
            )
        case .lists:
            return DictationDeterministicState(
                paragraphsEnabled: state.paragraphsEnabled,
                listsEnabled: false
            )
        }
    }

    private func renderedText(
        for targetState: DictationDeterministicState,
        sourceText: String,
        session: inout MacDictationChangeSession
    ) async -> String? {
        let key = MacDictationRenderedVariantKey(
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

        guard vibesCoordinator.canUseVibes else {
            return nil
        }

        let result = await vibesCoordinator.transform(sourceText, style: session.currentStyle)
        let replacementText = deterministicTextFormatter.textAdjustedForDeterministicState(
            result.finalText,
            state: targetState
        )
        guard replacementText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            return nil
        }

        session.renderedDeterministicVariants[key] = replacementText
        return replacementText
    }
}
