import Foundation
import KeyVoxTextComposition

protocol PasteSpacingCoordinating {
    func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool
    ) -> String
}

final class PasteSpacingCoordinator: PasteSpacingCoordinating {
    private let axInspector: PasteAXInspecting
    private let heuristicTTL: TimeInterval

    init(axInspector: PasteAXInspecting, heuristicTTL: TimeInterval) {
        self.axInspector = axInspector
        self.heuristicTTL = heuristicTTL
    }

    func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool
    ) -> String {
        let context = axInspector.focusedInsertionContext()

        if let context {
            if let selectionLength = context.selectionLength, selectionLength > 0 {
                return text
            }

            if let caretLocation = context.caretLocation, caretLocation == 0 {
                return text
            }

            if let previous = context.previousCharacter {
                let compositionContext = TextCompositionContext(
                    isAtDocumentStart: false,
                    previousCharacter: previous,
                    characterBeforePreviousCharacter: context.characterBeforePreviousCharacter,
                    previousNonWhitespaceCharacter: context.previousNonWhitespaceCharacter
                )
                return TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
                    to: text,
                    context: compositionContext
                )
            }
        }

        if context == nil {
            #if DEBUG
            print("[PasteSpacingCoordinator] suppress_last_insertion_fallback reason=focused_context_missing")
            #endif
            return text
        }

        guard let previous = lastInsertedTrailingCharacter else { return text }
        guard Date().timeIntervalSince(lastInsertionAt) <= heuristicTTL else { return text }
        guard let currentIdentity,
              let lastInsertionAppIdentity,
              identityMatcher(currentIdentity, lastInsertionAppIdentity) else {
            return text
        }

        return TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
            to: text,
            previousCharacter: previous
        )
    }
}
