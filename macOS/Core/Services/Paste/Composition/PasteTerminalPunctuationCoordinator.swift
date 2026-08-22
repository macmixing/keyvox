import KeyVoxTextComposition

protocol PasteTerminalPunctuationCoordinating {
    func resolveAdjacentTerminalPunctuation(in text: String) -> String
}

final class PasteTerminalPunctuationCoordinator: PasteTerminalPunctuationCoordinating {
    private let axInspector: PasteAXInspecting

    init(axInspector: PasteAXInspecting) {
        self.axInspector = axInspector
    }

    func resolveAdjacentTerminalPunctuation(in text: String) -> String {
        guard let context = axInspector.focusedInsertionContext(),
              let selectionLength = context.selectionLength else {
            return text
        }

        let resolution = TerminalPunctuationCompositionPolicy.resolve(
            text: text,
            followingCharacter: context.followingCharacter
        )
        guard resolution.shouldReplaceFollowingPunctuation else {
            return resolution.text
        }
        guard let selectionLocation = context.caretLocation,
              axInspector.includeFollowingCharacterInSelection(
                  at: selectionLocation,
                  selectionLength: selectionLength
              ) else {
            return text
        }
        return resolution.text
    }
}
