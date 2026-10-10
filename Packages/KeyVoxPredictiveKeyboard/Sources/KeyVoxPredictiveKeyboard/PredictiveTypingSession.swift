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
        /// The text the edit replaced, which backspace restores.
        let original: String
        let insertedText: String
        /// The words the edit replaced, which are not corrected that way again once the user
        /// restores them.
        let corrections: [Correction]
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

    private var wordTouches = TypedWordTouches()
    private var lastAutocorrection: AppliedAutocorrection?
    private var revisableWord: RevisableWord?
    /// What the last suggestion-bar tap inserted, ending in the space punctuation replaces.
    private var chosenText: String?
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
            self.lastAutocorrection = nil
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
        revisableWord = nil
        chosenText = nil
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
            heldBackCorrections: word.endsAtCursor ? memory.rejections.corrections(heldBackFor: word.text, at: now()) : []
        )
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
    /// separator. Backspace right after can undo what it changed. Punctuation right after a
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
        let replacesChosenSpace = currentWord.isEmpty
            && separator.allSatisfy(\.isWhitespace) == false
            && chosenText.map { textBeforeCursor?.hasSuffix($0) == true } == true
        let revised = revisableWord(before: context, textBeforeCursor: textBeforeCursor)
            .flatMap { revisable in
                revision.flatMap { $0 != revisable.word && allowsAutocorrection ? (revisable, $0) : nil }
            }
        let autocorrection = allowsAutocorrection ? autocorrection(in: result, for: currentWord) : nil
        wordTouches.reset()
        lastAutocorrection = nil
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
            let inserted = autocorrection + separator
            lastAutocorrection = AppliedAutocorrection(
                original: currentWord,
                insertedText: inserted,
                corrections: [Correction(typed: currentWord, correction: autocorrection)]
            )
            return TextEdit(deleteCount: currentWord.count, insertText: inserted)
        }
        let (previous, replacement) = revised
        let original = previous.word + " " + currentWord
        let inserted = replacement + " " + (autocorrection ?? currentWord) + separator
        lastAutocorrection = AppliedAutocorrection(
            original: original,
            insertedText: inserted,
            corrections: [Correction(typed: previous.word, correction: replacement)]
                + (autocorrection.map { [Correction(typed: currentWord, correction: $0)] } ?? [])
        )
        return TextEdit(deleteCount: original.count, insertText: inserted)
    }

    /// What backspace does instead of deleting one character, if anything: right after an
    /// autocorrection or revision it restores the typed words, and those corrections are not
    /// made again while the keyboard runs.
    public func backspaceEdit(textBeforeCursor: String?) -> TextEdit? {
        guard let lastAutocorrection,
              textBeforeCursor?.hasSuffix(lastAutocorrection.insertedText) == true else {
            return nil
        }
        self.lastAutocorrection = nil
        revisableWord = nil
        for correction in lastAutocorrection.corrections {
            memory.recordUndo(of: correction.correction, typed: correction.typed)
        }
        wordTouches.reset()
        return TextEdit(
            deleteCount: lastAutocorrection.insertedText.count,
            insertText: lastAutocorrection.original
        )
    }

    /// What tapping a suggestion-bar item inserts in place of the word the bar is for,
    /// followed by a space unless a space or punctuation already follows that word.
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
        if item.kind == .typed, word.endsAtCursor {
            return TextEdit(deleteCount: 0, insertText: space)
        }
        return TextEdit(
            deleteCount: word.charactersBeforeCursor,
            insertText: written + space,
            deleteAfterCount: word.charactersAfterCursor
        )
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
