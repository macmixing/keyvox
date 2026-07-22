import Foundation

public struct TextCompositionContext: Equatable, Sendable {
    public let isAtDocumentStart: Bool
    public let previousCharacter: Character?
    public let characterBeforePreviousCharacter: Character?
    public let previousNonWhitespaceCharacter: Character?
    public let isAfterNewline: Bool

    public init(
        isAtDocumentStart: Bool,
        previousCharacter: Character?,
        characterBeforePreviousCharacter: Character? = nil,
        previousNonWhitespaceCharacter: Character? = nil,
        isAfterNewline: Bool = false
    ) {
        self.isAtDocumentStart = isAtDocumentStart
        self.previousCharacter = previousCharacter
        self.characterBeforePreviousCharacter = characterBeforePreviousCharacter
        self.previousNonWhitespaceCharacter = previousNonWhitespaceCharacter
        self.isAfterNewline = isAfterNewline
    }

    public init(precedingText: String) {
        let previousCharacter = precedingText.last
        self.init(
            isAtDocumentStart: precedingText.isEmpty,
            previousCharacter: previousCharacter,
            characterBeforePreviousCharacter: precedingText.dropLast().last,
            previousNonWhitespaceCharacter: precedingText.reversed().first {
                $0.isWhitespace == false
            },
            isAfterNewline: precedingText.reversed().prefix(while: \.isWhitespace).contains {
                $0.isNewline
            }
        )
    }

    public static let documentStart = TextCompositionContext(
        isAtDocumentStart: true,
        previousCharacter: nil
    )
}

public enum LeadingCapitalizationScope: Sendable {
    case firstCharacter
    case firstLetterAfterLeadingWhitespace
}

private extension Character {
    var isNewline: Bool {
        unicodeScalars.allSatisfy(CharacterSet.newlines.contains)
    }
}
