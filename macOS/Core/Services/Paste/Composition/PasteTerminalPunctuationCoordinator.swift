import ApplicationServices
import KeyVoxTextComposition

struct PasteTerminalPunctuationInsertion {
    let text: String
    let targetElement: AXUIElement?
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
            return PasteTerminalPunctuationInsertion(text: text, targetElement: nil)
        }
        guard let context = axInspector.insertionContext(for: targetElement),
              let selectionLength = context.selectionLength else {
            return PasteTerminalPunctuationInsertion(text: text, targetElement: targetElement)
        }

        let resolution = TerminalPunctuationCompositionPolicy.resolve(
            text: text,
            followingCharacter: context.followingCharacter
        )
        guard resolution.shouldReplaceFollowingPunctuation else {
            return PasteTerminalPunctuationInsertion(
                text: resolution.text,
                targetElement: targetElement
            )
        }
        guard let selectionLocation = context.caretLocation,
              axInspector.setSelectedRange(
                  CFRange(location: selectionLocation, length: selectionLength + 1),
                  for: targetElement
              ) else {
            return PasteTerminalPunctuationInsertion(
                text: String(resolution.text.dropLast()),
                targetElement: targetElement
            )
        }
        return PasteTerminalPunctuationInsertion(
            text: resolution.text,
            targetElement: targetElement
        )
    }
}
