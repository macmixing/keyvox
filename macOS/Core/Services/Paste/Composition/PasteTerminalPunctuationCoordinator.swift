import ApplicationServices
import KeyVoxTextComposition

struct PasteTerminalPunctuationInsertion {
    let text: String
    let targetElement: AXUIElement?
    let followingCharacter: Character?
}

protocol PasteTerminalPunctuationCoordinating {
    func resolveAdjacentTerminalPunctuation(in text: String) -> PasteTerminalPunctuationInsertion
}

final class PasteTerminalPunctuationCoordinator: PasteTerminalPunctuationCoordinating {
    private let axInspector: PasteAXInspecting

    init(axInspector: PasteAXInspecting) {
        self.axInspector = axInspector
    }

    func resolveAdjacentTerminalPunctuation(in text: String) -> PasteTerminalPunctuationInsertion {
        guard let targetElement = axInspector.focusedUIElement() else {
            return PasteTerminalPunctuationInsertion(
                text: text,
                targetElement: nil,
                followingCharacter: nil
            )
        }
        guard let context = axInspector.insertionContext(for: targetElement) else {
            return PasteTerminalPunctuationInsertion(
                text: text,
                targetElement: targetElement,
                followingCharacter: nil
            )
        }
        guard let selectionLength = context.selectionLength else {
            return PasteTerminalPunctuationInsertion(
                text: text,
                targetElement: targetElement,
                followingCharacter: context.followingCharacter
            )
        }

        let resolution = TerminalPunctuationCompositionPolicy.resolve(
            text: text,
            followingCharacter: context.followingCharacter,
            followingNonWhitespaceCharacter: context.followingNonWhitespaceCharacter,
            followingText: context.followingText
        )
        guard resolution.shouldReplaceFollowingPunctuation else {
            return PasteTerminalPunctuationInsertion(
                text: resolution.text,
                targetElement: targetElement,
                followingCharacter: context.followingCharacter
            )
        }
        guard let selectionLocation = context.caretLocation,
              axInspector.setSelectedRange(
                  CFRange(location: selectionLocation, length: selectionLength + 1),
                  for: targetElement
              ) else {
            return PasteTerminalPunctuationInsertion(
                text: String(resolution.text.dropLast()),
                targetElement: targetElement,
                followingCharacter: context.followingCharacter
            )
        }
        return PasteTerminalPunctuationInsertion(
            text: resolution.text,
            targetElement: targetElement,
            followingCharacter: context.followingCharacter
        )
    }
}
