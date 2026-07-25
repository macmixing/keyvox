import Foundation

extension KeyboardViewController {
    func restoreAutomaticCorrectionIfAvailable() -> Bool {
        guard automaticCorrectionUndoStore.consumeUndoIfAvailable(
            documentContextBeforeInput: textInputController.documentContextBeforeInput,
            restore: { [weak self] original, replacement in
                self?.textInputController.restoreAutomaticCorrection(
                    original: original,
                    replacement: replacement
                ) ?? false
            }
        ) else {
            return false
        }

        keypressHaptics.emitKeypressIfEnabled()
        predictionCoordinator.synchronizeAfterDeletion(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        )
        refreshPredictionState()
        synchronizeTypingKeyPresentation()
        return true
    }

    func applyAutomaticCorrectionIfAvailable() -> Bool {
        guard let decision = predictionCoordinator.automaticCorrectionDecision(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        ) else {
            KeyboardTypingDiagnostics.log("correction_apply_skipped", fields: [
                "reason": "no_decision",
            ])
            return false
        }
        let startedAt = ProcessInfo.processInfo.systemUptime
        guard textInputController.replaceCurrentWord(
            decision.original,
            with: decision.replacement,
            appendingSpace: true
        ) else {
            KeyboardTypingDiagnostics.log("correction_apply_skipped", fields: [
                "reason": "replacement_failed",
                "original": decision.original,
                "replacement": decision.replacement,
            ])
            return false
        }
        KeyboardTypingDiagnostics.log("correction_applied", fields: [
            "original": decision.original,
            "replacement": decision.replacement,
            "probability": decision.probability,
            "duration_ms": ((ProcessInfo.processInfo.systemUptime - startedAt) * 100_000)
                .rounded() / 100,
        ])

        keypressHaptics.emitKeypressIfEnabled()
        automaticCorrectionUndoStore.record(
            original: decision.original,
            replacement: decision.replacement
        )
        predictionCoordinator.reset()
        letterCaseController.synchronize(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        )
        refreshPredictionState()
        synchronizeTypingKeyPresentation()
        return true
    }

    func updatePredictionAfterHandledKey(
        _ kind: KeyboardKeyKind,
        activation: KeyboardKeyActivation
    ) {
        switch kind {
        case let .character(value):
            automaticCorrectionUndoStore.invalidate()
            predictionCoordinator.recordCharacter(
                value,
                location: activation.location,
                isLongPressAlternate: activation.isLongPressAlternate,
                documentContextBeforeInput: textInputController.documentContextBeforeInput
            )
            if symbolPage == .alphabetic {
                letterCaseController.consumeInsertedCharacter()
            }
        case .delete:
            automaticCorrectionUndoStore.invalidate()
            predictionCoordinator.synchronizeAfterDeletion(
                documentContextBeforeInput: textInputController.documentContextBeforeInput
            )
        case .space, .returnKey:
            automaticCorrectionUndoStore.invalidate()
            predictionCoordinator.reset()
            letterCaseController.synchronize(
                documentContextBeforeInput: textInputController.documentContextBeforeInput
            )
        case .abc:
            letterCaseController.synchronize(
                documentContextBeforeInput: textInputController.documentContextBeforeInput
            )
        case .shift, .alternateSymbols, .numberSymbols, .nextKeyboard:
            break
        }
        refreshPredictionState()
    }

    func handlePredictionChoice(_ choice: KeyboardPredictionChoice) {
        var prediction = choice.text
        if choice.kind == .nextWord,
           letterCaseController.letterCase.usesUppercaseLetters,
           let first = prediction.first {
            prediction = first.uppercased() + prediction.dropFirst()
        }
        let currentWord = predictionCoordinator.currentWord(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        )
        guard textInputController.insertPrediction(
            prediction,
            replacing: currentWord
        ) else {
            return
        }
        automaticCorrectionUndoStore.invalidate()
        predictionCoordinator.reset()
        letterCaseController.synchronize(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        )
        refreshPredictionState()
        synchronizeTypingKeyPresentation()
    }

    func refreshPredictionState() {
        guard symbolPage == .alphabetic else {
            predictionCoordinator.reset()
            return
        }
        predictionCoordinator.refresh(
            documentContextBeforeInput: textInputController.documentContextBeforeInput,
            capitalizesNextWord: letterCaseController.letterCase.usesUppercaseLetters
        )
    }
}
