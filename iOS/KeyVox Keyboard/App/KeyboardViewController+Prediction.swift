import Foundation
import UIKit

extension KeyboardViewController {
    func loadSupplementaryPredictionLexicon() {
        requestSupplementaryLexicon { [weak self] lexicon in
            guard let self else { return }
            let entries = lexicon.entries.map {
                KeyboardSupplementaryLexicon.Entry(
                    userInput: $0.userInput,
                    documentText: $0.documentText
                )
            }
            predictionCoordinator.updateSupplementaryLexicon(
                KeyboardSupplementaryLexicon(entries: entries)
            )
            refreshPredictionState()
        }
    }

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
        let context = textInputController.documentContextBeforeInput
        let decision = userDictionaryCorrectionController.correction(
            documentContextBeforeInput: context
        ) ?? predictionCoordinator.automaticCorrectionDecision(
            documentContextBeforeInput: context
        )
        guard let decision else {
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
        predictionCoordinator.advanceAfterWordBoundary(
            documentContextBeforeInput: textInputController.documentContextBeforeInput
        )
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
        case .space:
            automaticCorrectionUndoStore.invalidate()
            predictionCoordinator.advanceAfterWordBoundary(
                documentContextBeforeInput: textInputController.documentContextBeforeInput
            )
            letterCaseController.synchronize(
                documentContextBeforeInput: textInputController.documentContextBeforeInput
            )
        case .returnKey:
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
