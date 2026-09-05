import Foundation

public struct TextCompositionContext: Equatable, Sendable {
    public let isAtDocumentStart: Bool
    public let previousCharacter: Character?
    public let characterBeforePreviousCharacter: Character?
    public let previousNonWhitespaceCharacter: Character?
    public let characterBeforePreviousNonWhitespaceCharacter: Character?
    public let characterBeforeTrailingHyphenSequence: Character?
    public let isPreviousNonWhitespaceCharacterAtLineStart: Bool
    public let isAfterNewline: Bool

    public init(
        isAtDocumentStart: Bool,
        previousCharacter: Character?,
        characterBeforePreviousCharacter: Character? = nil,
        previousNonWhitespaceCharacter: Character? = nil,
        characterBeforePreviousNonWhitespaceCharacter: Character? = nil,
        characterBeforeTrailingHyphenSequence: Character? = nil,
        isPreviousNonWhitespaceCharacterAtLineStart: Bool = false,
        isAfterNewline: Bool = false
    ) {
        self.isAtDocumentStart = isAtDocumentStart
        self.previousCharacter = previousCharacter
        self.characterBeforePreviousCharacter = characterBeforePreviousCharacter
        self.previousNonWhitespaceCharacter = previousNonWhitespaceCharacter
        self.characterBeforePreviousNonWhitespaceCharacter = characterBeforePreviousNonWhitespaceCharacter
        self.characterBeforeTrailingHyphenSequence = characterBeforeTrailingHyphenSequence
            ?? Self.characterBeforeSingleTrailingHyphen(
                previousNonWhitespaceCharacter: previousNonWhitespaceCharacter,
                characterBeforePreviousNonWhitespaceCharacter: characterBeforePreviousNonWhitespaceCharacter
            )
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
            characterBeforeTrailingHyphenSequence: Self.characterBeforeTrailingHyphenSequence(
                in: precedingText
            ),
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

    public static func characterBeforeTrailingHyphenSequence(
        in text: String
    ) -> Character? {
        let nonWhitespaceCharacters = text.reversed().filter { $0.isWhitespace == false }
        let trailingHyphens = nonWhitespaceCharacters.prefix {
            TextCompositionCharacterClassifier.isHyphenSeparator($0)
        }
        guard trailingHyphens.isEmpty == false else { return nil }
        return nonWhitespaceCharacters.dropFirst(trailingHyphens.count).first
    }

    private static func characterBeforeSingleTrailingHyphen(
        previousNonWhitespaceCharacter: Character?,
        characterBeforePreviousNonWhitespaceCharacter: Character?
    ) -> Character? {
        guard let previousNonWhitespaceCharacter,
              TextCompositionCharacterClassifier.isHyphenSeparator(
                  previousNonWhitespaceCharacter
              ),
              characterBeforePreviousNonWhitespaceCharacter.map(
                  TextCompositionCharacterClassifier.isHyphenSeparator
              ) != true else {
            return nil
        }

        return characterBeforePreviousNonWhitespaceCharacter
    }
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
