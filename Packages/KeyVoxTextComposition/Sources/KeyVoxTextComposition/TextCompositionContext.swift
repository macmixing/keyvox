import Foundation

public struct TextCompositionContext: Equatable, Sendable {
    public let isAtDocumentStart: Bool
    public let previousCharacter: Character?
    public let characterBeforePreviousCharacter: Character?
    public let previousNonWhitespaceCharacter: Character?
    public let characterBeforePreviousNonWhitespaceCharacter: Character?
    public let isPreviousNonWhitespaceCharacterAtLineStart: Bool
    public let isAfterNewline: Bool

    public init(
        isAtDocumentStart: Bool,
        previousCharacter: Character?,
        characterBeforePreviousCharacter: Character? = nil,
        previousNonWhitespaceCharacter: Character? = nil,
        characterBeforePreviousNonWhitespaceCharacter: Character? = nil,
        isPreviousNonWhitespaceCharacterAtLineStart: Bool = false,
        isAfterNewline: Bool = false
    ) {
        self.isAtDocumentStart = isAtDocumentStart
        self.previousCharacter = previousCharacter
        self.characterBeforePreviousCharacter = characterBeforePreviousCharacter
        self.previousNonWhitespaceCharacter = previousNonWhitespaceCharacter
        self.characterBeforePreviousNonWhitespaceCharacter = characterBeforePreviousNonWhitespaceCharacter
        self.isPreviousNonWhitespaceCharacterAtLineStart = isPreviousNonWhitespaceCharacterAtLineStart
        self.isAfterNewline = isAfterNewline
    }

    public init(precedingText: String) {
        let previousCharacter = precedingText.last
        let previousNonWhitespaceIndex = precedingText.lastIndex {
            $0.isWhitespace == false
        }
        let nonWhitespaceCharacters = precedingText.reversed().filter { $0.isWhitespace == false }
        let isPreviousNonWhitespaceCharacterAtLineStart = previousNonWhitespaceIndex.map {
            precedingText[..<$0].reversed().prefix(while: \.isWhitespace).contains {
                $0.isNewline
            }
        } ?? false
        self.init(
            isAtDocumentStart: precedingText.isEmpty,
            previousCharacter: previousCharacter,
            characterBeforePreviousCharacter: precedingText.dropLast().last,
            previousNonWhitespaceCharacter: nonWhitespaceCharacters.first,
            characterBeforePreviousNonWhitespaceCharacter: nonWhitespaceCharacters.dropFirst().first,
            isPreviousNonWhitespaceCharacterAtLineStart: isPreviousNonWhitespaceCharacterAtLineStart,
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
