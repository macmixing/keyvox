import Foundation
import KeyVoxTextComposition

protocol PasteCapitalizationCoordinating {
    func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        lastInsertedTrailingNonWhitespaceCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool,
        shouldPreserveLeadingCapitalization: (String) -> Bool
    ) -> String
}

final class PasteCapitalizationCoordinator: PasteCapitalizationCoordinating {
    private let axInspector: PasteAXInspecting
    private let heuristicTTL: TimeInterval
    private let clockNow: () -> Date

    init(
        axInspector: PasteAXInspecting,
        heuristicTTL: TimeInterval,
        clockNow: @escaping () -> Date = Date.init
    ) {
        self.axInspector = axInspector
        self.heuristicTTL = heuristicTTL
        self.clockNow = clockNow
    }

    func normalizeLeadingCapitalizationIfNeeded(
        in text: String,
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        lastInsertedTrailingNonWhitespaceCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool,
        shouldPreserveLeadingCapitalization: (String) -> Bool
    ) -> String {
        let sentenceStart = isSentenceStart(
            currentIdentity: currentIdentity,
            lastInsertionAppIdentity: lastInsertionAppIdentity,
            lastInsertionAt: lastInsertionAt,
            lastInsertedTrailingCharacter: lastInsertedTrailingCharacter,
            lastInsertedTrailingNonWhitespaceCharacter: lastInsertedTrailingNonWhitespaceCharacter,
            identityMatcher: identityMatcher
        )
        return TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
            in: text,
            isSentenceStart: sentenceStart,
            scope: .firstLetterAfterLeadingWhitespace,
            preserveLeadingCapitalization: shouldPreserveLeadingCapitalization(text)
        )
    }

    private func isSentenceStart(
        currentIdentity: PasteAppIdentity?,
        lastInsertionAppIdentity: PasteAppIdentity?,
        lastInsertionAt: Date,
        lastInsertedTrailingCharacter: Character?,
        lastInsertedTrailingNonWhitespaceCharacter: Character?,
        identityMatcher: (PasteAppIdentity, PasteAppIdentity) -> Bool
    ) -> Bool {
        let context = axInspector.focusedInsertionContext()
        if let context {
            if let caretLocation = context.caretLocation, caretLocation == 0 {
                return true
            }

            let compositionContext = compositionContext(from: context)

            if TextCompositionPolicy.isImmediatelyAfterOpeningQuote(compositionContext) {
                return true
            }

            if TextCompositionPolicy.isImmediatelyAfterTerminalPunctuationAndDelimiter(
                compositionContext
            ) {
                return true
            }

            if compositionContext.previousCharacter != nil
                || compositionContext.previousNonWhitespaceCharacter != nil {
                return TextCompositionPolicy.isSentenceStart(in: compositionContext)
            }
        }

        if context == nil {
            #if DEBUG
            print("[PasteCapitalizationCoordinator] suppress_last_insertion_fallback reason=focused_context_missing")
            #endif
            return true
        }

        if lastInsertedTrailingCharacter?.isNewline == true {
            return true
        }

        guard let currentIdentity,
              let lastInsertionAppIdentity,
              identityMatcher(currentIdentity, lastInsertionAppIdentity),
              clockNow().timeIntervalSince(lastInsertionAt) <= heuristicTTL else {
            return true
        }

        let boundaryCharacter = lastInsertedTrailingNonWhitespaceCharacter
            ?? lastInsertedTrailingCharacter.flatMap { $0.isWhitespace ? nil : $0 }
        return boundaryCharacter.map(TextCompositionPolicy.isSentenceBoundary) ?? false
    }

    private func compositionContext(from context: PasteInsertionContext) -> TextCompositionContext {
        let precedingCharacters = [
            context.previousCharacter,
            context.characterBeforePreviousCharacter
        ].compactMap { $0 }.filter { !$0.isInvisibleFormatCharacter }
        let precedingNonWhitespaceCharacters = [
            context.previousNonWhitespaceCharacter,
            context.characterBeforePreviousNonWhitespaceCharacter
        ].compactMap { $0 }.filter { !$0.isInvisibleFormatCharacter }
        let previousCharacter = precedingCharacters.first
        let characterBeforePreviousCharacter = precedingCharacters.dropFirst().first

        return TextCompositionContext(
            isAtDocumentStart: false,
            previousCharacter: previousCharacter,
            characterBeforePreviousCharacter: characterBeforePreviousCharacter,
            previousNonWhitespaceCharacter: precedingNonWhitespaceCharacters.first,
            characterBeforePreviousNonWhitespaceCharacter: precedingNonWhitespaceCharacters.dropFirst().first,
            isPreviousNonWhitespaceCharacterAtLineStart: context.isPreviousNonWhitespaceCharacterAtLineStart,
            isAfterNewline: previousCharacter?.isNewline == true
                || characterBeforePreviousCharacter?.isNewline == true
        )
    }
}

private extension Character {
    var isNewline: Bool {
        unicodeScalars.allSatisfy(CharacterSet.newlines.contains)
    }

    var isInvisibleFormatCharacter: Bool {
        unicodeScalars.allSatisfy { $0.properties.generalCategory == .format }
    }
}
