import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// The typing state of one text field, shared by every KeyVox keyboard host.
///
/// The host reports what happened (a letter was tapped, the text changed) and asks what
/// to do (what space, backspace, or a suggestion tap should change). Every answer is a
/// `TextEdit` the host applies at the cursor. Use from one thread only.
public final class PredictiveTypingSession {
    /// A typed word and what an edit replaced it with.
    private struct Correction {
        let typed: String
        let correction: String
    }

    private struct AppliedAutocorrection {
        /// The text the edit replaced, which the suggestion bar offers to put back.
        let original: String
        /// The words the edit inserted, without the separator after them.
        let correctedText: String
        let separator: String
        /// The words the edit replaced, which are not corrected that way again once the user
        /// puts them back.
        let corrections: [Correction]

        var insertedText: String { correctedText + separator }
    }

    /// The word the suggestion bar is for: a selected word, the whole word around the cursor
    /// when the cursor is inside one, or otherwise the letters right before the cursor.
    private struct SuggestedWord {
        let text: String
        /// Characters of the word before and after the cursor, which replacing it deletes. A
        /// selected word has none, since inserting replaces the selection.
        let charactersBeforeCursor: Int
        let charactersAfterCursor: Int
        /// The word ends at the cursor, as while typing it, so space may autocorrect it.
        let endsAtCursor: Bool
    }

    /// A word space finished as typed, which the word after it may still revise.
    private struct RevisableWord {
        let word: String
        let touches: [CGPoint]
        let previousWords: [String]
    }

    private static let pickedWordSpaceCharacters = try? CharacterList.takingPickedWordSpace()
    private static let spacedFromPickedWordCharacters = try? CharacterList.spacedFromPickedWord()
    private static let noNextWordCharacters = try? CharacterList.withoutNextWords()

    private var wordTouches = TypedWordTouches()
    private var lastAutocorrection: AppliedAutocorrection?
    /// The last autocorrection once the user deleted the separator after it, which the suggestion
    /// bar offers to undo while the text still ends with the corrected words.
    private var revertibleAutocorrection: AppliedAutocorrection?
    private var revisableWord: RevisableWord?
    /// What the last suggestion-bar tap inserted, ending in the space punctuation replaces.
    private var chosenText: String?
    /// The words the user picked from the suggestion bar in a row, as their taps inserted them;
    /// they count while the text before the cursor still ends with them (`RepeatedPicks`).
    private var pickedText = ""
    /// Drawn when a run of picks starts (`PredictionRequest.pickRun`).
    private var pickRun = 0
    /// The corrections the user turned down and the words they keep typing, shared with every
    /// session while the keyboard runs.
    private let memory: TypingMemory
    private let now: () -> Date

    public init(memory: TypingMemory = TypingMemory(), now: @escaping () -> Date = { Date() }) {
        self.memory = memory
        self.now = now
    }

    /// Call after a tapped character has been inserted.
    public func recordTap(at location: CGPoint, textBeforeCursor: String?) {
        lastAutocorrection = nil
        revertibleAutocorrection = nil
        chosenText = nil
        let context = TypingTextContext(textBeforeCursor: textBeforeCursor)
        if context.currentWord.isEmpty {
            wordTouches.reset()
        } else {
            wordTouches.recordTap(at: location, currentWord: context.currentWord)
        }
    }

    /// Call after any change the session did not ask for, such as a cursor move.
    public func textDidChange(textBeforeCursor: String?) {
        if let lastAutocorrection,
           textBeforeCursor?.hasSuffix(lastAutocorrection.insertedText) != true {
            // Deleting the separator keeps the correction, as on the system keyboard; the bar
            // then offers to put back what was typed.
            revertibleAutocorrection = textBeforeCursor?.hasSuffix(lastAutocorrection.correctedText) == true
                ? lastAutocorrection
                : nil
            self.lastAutocorrection = nil
        }
        if let revertibleAutocorrection,
           textBeforeCursor?.hasSuffix(revertibleAutocorrection.correctedText) != true {
            self.revertibleAutocorrection = nil
        }
        if let chosenText, textBeforeCursor?.hasSuffix(chosenText) != true {
            self.chosenText = nil
        }
        wordTouches.synchronize(currentWord: TypingTextContext(textBeforeCursor: textBeforeCursor).currentWord)
    }

    /// Call when the field changes or the keyboard reappears.
    public func reset() {
        wordTouches.reset()
        lastAutocorrection = nil
        revertibleAutocorrection = nil
        revisableWord = nil
        chosenText = nil
        pickedText = ""
    }

    /// What to suggest for the text around the cursor. A selected word, or one the cursor
    /// was moved into, is suggested for as a whole, such as a misspelled word the user tapped;
    /// space never autocorrects it.
    public func request(
        textBeforeCursor: String?,
        selectedText: String? = nil,
        textAfterCursor: String? = nil
    ) -> PredictionRequest {
        let context = TypingTextContext(
            textBeforeCursor: textBeforeCursor,
            selectedText: selectedText,
            textAfterCursor: textAfterCursor
        )
        let word = Self.suggestedWord(in: context)
        let isAllLetters = word.text.allSatisfy(\.isLetter)
        return PredictionRequest(
            currentWord: word.text,
            touches: word.endsAtCursor && isAllLetters ? wordTouches.touches(for: word.text) : [],
            previousWords: context.previousWords,
            keepsTypedWord: word.endsAtCursor == false,
            isAtSentenceStart: context.isAtSentenceStart,
            previousSentence: context.isAtSentenceStart ? SentenceEnding(before: textBeforeCursor ?? "") : nil,
            heldBackCorrections: word.endsAtCursor ? memory.rejections.corrections(heldBackFor: word.text, at: now()) : [],
            pickedWords: word.text.isEmpty && pickedText.isEmpty == false && (textBeforeCursor ?? "").hasSuffix(pickedText)
                ? TypingTextContext.wordsNewestFirst(in: pickedText)
                : [],
            pickRun: pickRun,
            offersNextWords: word.text.isEmpty == false
                || textBeforeCursor?.last.map { Self.noNextWordCharacters?.contains(String($0)) != true } ?? true,
            revertibleText: word.endsAtCursor ? revertibleAutocorrection(endingAt: textBeforeCursor)?.original : nil
        )
    }

    /// The autocorrection whose separator the user deleted, while the text still ends with the
    /// corrected words.
    private func revertibleAutocorrection(endingAt textBeforeCursor: String?) -> AppliedAutocorrection? {
        guard let revertibleAutocorrection,
              textBeforeCursor?.hasSuffix(revertibleAutocorrection.correctedText) == true else {
            return nil
        }
        return revertibleAutocorrection
    }

    /// Whether `result` was computed for the text as it is now.
    public func isCurrent(
        _ result: PredictionResult,
        textBeforeCursor: String?,
        selectedText: String? = nil,
        textAfterCursor: String? = nil
    ) -> Bool {
        result.request == request(
            textBeforeCursor: textBeforeCursor,
            selectedText: selectedText,
            textAfterCursor: textAfterCursor
        )
    }

    /// What to reconsider when the current word ends: the word right before it, if space
    /// left that word as typed and the text still reads that word, a space, and the
    /// current word. `result` supplies the current word's autocorrection, if any.
    public func revisionRequest(textBeforeCursor: String?, result: PredictionResult?) -> RevisionRequest? {
        let context = TypingTextContext(textBeforeCursor: textBeforeCursor)
        guard let revisable = revisableWord(before: context, textBeforeCursor: textBeforeCursor) else {
            return nil
        }
        return RevisionRequest(
            word: revisable.word,
            touches: revisable.touches,
            previousWords: revisable.previousWords,
            followingWord: autocorrection(in: result, for: context.currentWord) ?? context.currentWord,
            heldBackCorrections: memory.rejections.corrections(heldBackFor: revisable.word, at: now())
        )
    }

    /// What typing `separator` (a space, return, or punctuation) after the current word
    /// inserts: the autocorrection from `result` when it was computed for this word, and
    /// `revision` in place of the word before it when one was decided, followed by the
    /// separator. Deleting the separator right after keeps what it changed, and the suggestion bar
    /// then offers to put back what was typed (see `choiceEdit`). Punctuation right after a
    /// suggestion-bar tap replaces the space the tap added. A word left as typed teaches the
    /// keyboard (see `recordKeptWord`), also where `allowsAutocorrection` is false and `result`
    /// is only read to tell.
    public func wordBoundaryEdit(
        separator: String,
        textBeforeCursor: String?,
        result: PredictionResult?,
        revision: String? = nil,
        allowsAutocorrection: Bool = true
    ) -> TextEdit {
        let context = TypingTextContext(textBeforeCursor: textBeforeCursor)
        let currentWord = context.currentWord
        let touches = wordTouches.touches(for: currentWord)
        let replacesChosenSpace = takesChosenSpace(separator, currentWord: currentWord, textBeforeCursor: textBeforeCursor)
        let revised = revisableWord(before: context, textBeforeCursor: textBeforeCursor)
            .flatMap { revisable in
                revision.flatMap { $0 != revisable.word && allowsAutocorrection ? (revisable, $0) : nil }
            }
        let autocorrection = allowsAutocorrection ? autocorrection(in: result, for: currentWord) : nil
        wordTouches.reset()
        lastAutocorrection = nil
        revertibleAutocorrection = nil
        revisableWord = nil
        chosenText = nil

        if autocorrection == nil {
            recordKeptWord(currentWord, result: result)
        } else if let autocorrection, autocorrection.lowercased() == currentWord.lowercased(),
                  result?.typedWordKind == .unknown {
            // A learned word given the user's capitals is still a use of it.
            recordKeptWord(currentWord, writtenAs: autocorrection, result: result)
        }
        // A word the user turned a correction of down is not revised by the word after it.
        if autocorrection == nil, separator == " ", currentWord.isEmpty == false,
           memory.rejections.corrections(heldBackFor: currentWord, at: now()).isEmpty {
            revisableWord = RevisableWord(
                word: currentWord,
                touches: touches,
                previousWords: revised.map { [$0.1] + context.previousWords.dropFirst() }
                    ?? context.previousWords
            )
        }

        guard let revised else {
            guard let autocorrection else {
                return TextEdit(deleteCount: replacesChosenSpace ? 1 : 0, insertText: separator)
            }
            let applied = AppliedAutocorrection(
                original: currentWord,
                correctedText: autocorrection,
                separator: separator,
                corrections: [Correction(typed: currentWord, correction: autocorrection)]
            )
            lastAutocorrection = applied
            return TextEdit(deleteCount: currentWord.count, insertText: applied.insertedText)
        }
        let (previous, replacement) = revised
        let original = previous.word + " " + currentWord
        let applied = AppliedAutocorrection(
            original: original,
            correctedText: replacement + " " + (autocorrection ?? currentWord),
            separator: separator,
            corrections: [Correction(typed: previous.word, correction: replacement)]
                + (autocorrection.map { [Correction(typed: currentWord, correction: $0)] } ?? [])
        )
        lastAutocorrection = applied
        return TextEdit(deleteCount: original.count, insertText: applied.insertedText)
    }

    /// What typing `character`, one that does not end a word, does right after a word picked from
    /// the suggestion bar when it takes the place of the space the pick added, as an apostrophe
    /// or a closing square bracket does; nil when it follows the space.
    /// - Parameter typesExactly: Whether the character types as shown instead of as a curly quote.
    public func pickedWordSpaceEdit(character: String, typesExactly: Bool, textBeforeCursor: String?) -> TextEdit? {
        let currentWord = TypingTextContext(textBeforeCursor: textBeforeCursor).currentWord
        guard takesChosenSpace(character, currentWord: currentWord, textBeforeCursor: textBeforeCursor) else {
            return nil
        }
        chosenText = nil
        let textBeforeSpace = textBeforeCursor.map { String($0.dropLast()) }
        return TextEdit(
            deleteCount: 1,
            insertText: typesExactly ? character : SmartQuotes.text(for: character, after: textBeforeSpace)
        )
    }

    /// Whether `character`, typed with no word begun, takes the place of the space the last
    /// suggestion-bar tap added.
    private func takesChosenSpace(_ character: String, currentWord: String, textBeforeCursor: String?) -> Bool {
        currentWord.isEmpty
            && Self.pickedWordSpaceCharacters?.contains(character) == true
            && chosenText.map { textBeforeCursor?.hasSuffix($0) == true } == true
    }

    /// What tapping a suggestion-bar item inserts in place of the word the bar is for,
    /// followed by a space unless a space or punctuation already follows that word. Right after
    /// a mark a picked word is spaced away from, such as a comma, the tap only adds the space.
    /// Tapping what was typed before an autocorrection whose separator the user deleted puts
    /// the typed words back, and those corrections are not made again while the keyboard runs.
    ///
    /// Keeping the typed word while `result` waits to correct it turns that correction down for
    /// good, and teaches the keyboard the word as typed (see `recordKeptWord`); choosing a
    /// correction the user turned down lets it apply again.
    /// - Parameters:
    ///   - result: The suggestions the bar shows, if computed for the text as it is now.
    ///   - allowsAutocorrection: Whether space applies the bar's autocorrection here.
    public func choiceEdit(
        _ item: SuggestionBar.Item,
        textBeforeCursor: String?,
        selectedText: String? = nil,
        textAfterCursor: String? = nil,
        result: PredictionResult? = nil,
        allowsAutocorrection: Bool = true
    ) -> TextEdit {
        let context = TypingTextContext(
            textBeforeCursor: textBeforeCursor,
            selectedText: selectedText,
            textAfterCursor: textAfterCursor
        )
        let word = Self.suggestedWord(in: context)
        if item.kind == .revert, word.endsAtCursor,
           let reverted = revertibleAutocorrection(endingAt: textBeforeCursor) {
            return revertEdit(reverted, followingText: context.followingText)
        }
        // Right after a mark a picked word is spaced away from, the first tap only adds the
        // space, as on the system keyboard; the next tap picks.
        if word.text.isEmpty, let mark = textBeforeCursor?.last,
           Self.spacedFromPickedWordCharacters?.contains(String(mark)) == true {
            return TextEdit(deleteCount: 0, insertText: " ")
        }
        lastAutocorrection = nil
        revisableWord = nil
        wordTouches.reset()
        let textAfterWord = context.followingText.dropFirst(word.charactersAfterCursor)
        let isSeparated = textAfterWord.first.map { TypingTextContext.isWordCharacter($0) == false } ?? false
        let space = isSeparated ? "" : " "
        let written: String
        if item.kind == .typed {
            if word.endsAtCursor {
                if allowsAutocorrection, let correction = autocorrection(in: result, for: word.text) {
                    memory.recordRejection(of: correction, typed: word.text, at: now())
                }
                recordKeptWord(word.text, result: result)
            }
            written = word.text
        } else {
            memory.recordAcceptance(of: item.text, typed: word.text)
            written = item.text
        }
        chosenText = textAfterWord.isEmpty ? written + space : nil
        // A pick right after the earlier picks continues them; one anywhere else starts over.
        let textBeforeWord = (textBeforeCursor ?? "").dropLast(word.charactersBeforeCursor)
        let continuesPicks = pickedText.isEmpty == false && textBeforeWord.hasSuffix(pickedText)
        if continuesPicks == false {
            pickRun = Int.random(in: Int.min...Int.max)
        }
        pickedText = word.endsAtCursor && textAfterWord.isEmpty
            ? (continuesPicks ? pickedText : "") + written + space
            : ""
        if item.kind == .typed, word.endsAtCursor {
            return TextEdit(deleteCount: 0, insertText: space)
        }
        return TextEdit(
            deleteCount: word.charactersBeforeCursor,
            insertText: written + space,
            deleteAfterCount: word.charactersAfterCursor
        )
    }

    /// Puts back the words `reverted` replaced, followed by a space like any pick, and holds its
    /// corrections back while the keyboard runs.
    private func revertEdit(_ reverted: AppliedAutocorrection, followingText: String) -> TextEdit {
        revertibleAutocorrection = nil
        lastAutocorrection = nil
        revisableWord = nil
        wordTouches.reset()
        pickedText = ""
        for correction in reverted.corrections {
            memory.recordUndo(of: correction.correction, typed: correction.typed)
        }
        let isSeparated = followingText.first.map { TypingTextContext.isWordCharacter($0) == false } ?? false
        let space = isSeparated ? "" : " "
        chosenText = followingText.isEmpty ? reverted.original + space : nil
        return TextEdit(deleteCount: reverted.correctedText.count, insertText: reverted.original + space)
    }

    private static func suggestedWord(in context: TypingTextContext) -> SuggestedWord {
        if let selected = context.selectedWord {
            return SuggestedWord(
                text: selected,
                charactersBeforeCursor: 0,
                charactersAfterCursor: 0,
                endsAtCursor: false
            )
        }
        guard context.currentWord.isEmpty == false, context.restOfWord.isEmpty == false else {
            return SuggestedWord(
                text: context.currentWord,
                charactersBeforeCursor: context.currentWord.count,
                charactersAfterCursor: 0,
                endsAtCursor: true
            )
        }
        return SuggestedWord(
            text: context.currentWord + context.restOfWord,
            charactersBeforeCursor: context.currentWord.count,
            charactersAfterCursor: context.restOfWord.count,
            endsAtCursor: false
        )
    }

    /// The revisable word, if the text still reads it, one space, and the current word.
    private func revisableWord(
        before context: TypingTextContext,
        textBeforeCursor: String?
    ) -> RevisableWord? {
        guard let revisableWord,
              context.currentWord.isEmpty == false,
              context.previousWords.first == revisableWord.word,
              textBeforeCursor?.hasSuffix(revisableWord.word + " " + context.currentWord) == true else {
            return nil
        }
        return revisableWord
    }

    /// What `word`, left as typed or `written` with a learned word's capitals, teaches the
    /// keyboard when `result` was computed for it: a word it does not know counts toward learning
    /// it, after the word before it, as written, even with a capital that only starts the
    /// sentence, as on the system keyboard; a dictionary word written with capitals within a
    /// sentence teaches how the user writes it.
    private func recordKeptWord(_ word: String, writtenAs written: String? = nil, result: PredictionResult?) {
        guard let result, result.request.currentWord == word,
              word.count > 1, word.contains(where: \.isLetter) else { return }
        let request = result.request
        switch result.typedWordKind {
        case .unknown:
            memory.recordUse(of: written ?? word, after: request.isAtSentenceStart ? nil : request.previousWords.first, at: now())
        case .dictionaryWord where request.isAtSentenceStart == false && word != word.lowercased():
            memory.recordCapitalUse(of: word, at: now())
        case .dictionaryWord, .usersWord:
            break
        }
    }

    private func autocorrection(in result: PredictionResult?, for currentWord: String) -> String? {
        guard let result,
              result.request.currentWord == currentWord,
              let replacement = result.autocorrection,
              replacement != currentWord else {
            return nil
        }
        return replacement
    }
}
