#if canImport(CoreGraphics)
import CoreGraphics
#else
import Foundation
#endif

/// The typing state of one text field, shared by every KeyVox keyboard host.
///
/// The host reports what happened (a letter was tapped, the text changed) and asks what
/// to do (what space, backspace, or a suggestion tap should change). Every answer is a
/// `TextEdit` the host applies at the cursor. Use from one thread only.
public final class PredictiveTypingSession {
    private struct AppliedAutocorrection {
        /// The text the edit replaced, which backspace restores.
        let original: String
        let insertedText: String
        /// The typed words the edit replaced, kept as typed once the user restores them.
        let replacedWords: [String]
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
    /// Words whose autocorrection the user undid; space keeps them as typed.
    private var keptWords: Set<String> = []

    public init() {}

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
        keptWords = []
    }

    public func request(textBeforeCursor: String?) -> PredictionRequest {
        let context = TypingTextContext(textBeforeCursor: textBeforeCursor)
        let isAllLetters = context.currentWord.allSatisfy(\.isLetter)
        return PredictionRequest(
            currentWord: context.currentWord,
            touches: isAllLetters ? wordTouches.touches(for: context.currentWord) : [],
            previousWords: context.previousWords,
            keepsTypedWord: keptWords.contains(context.currentWord.lowercased()),
            isAtSentenceStart: context.isAtSentenceStart
        )
    }

    /// Whether `result` was computed for the text as it is now.
    public func isCurrent(_ result: PredictionResult, textBeforeCursor: String?) -> Bool {
        result.request == request(textBeforeCursor: textBeforeCursor)
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
            followingWord: autocorrection(in: result, for: context.currentWord) ?? context.currentWord
        )
    }

    /// What typing `separator` (a space, return, or punctuation) after the current word
    /// inserts: the autocorrection from `result` when it was computed for this word, and
    /// `revision` in place of the word before it when one was decided, followed by the
    /// separator. Backspace right after can undo what it changed. Punctuation right after a
    /// suggestion-bar tap replaces the space the tap added.
    public func wordBoundaryEdit(
        separator: String,
        textBeforeCursor: String?,
        result: PredictionResult?,
        revision: String? = nil
    ) -> TextEdit {
        let context = TypingTextContext(textBeforeCursor: textBeforeCursor)
        let currentWord = context.currentWord
        let touches = wordTouches.touches(for: currentWord)
        let replacesChosenSpace = currentWord.isEmpty
            && separator.allSatisfy(\.isWhitespace) == false
            && chosenText.map { textBeforeCursor?.hasSuffix($0) == true } == true
        let revised = revisableWord(before: context, textBeforeCursor: textBeforeCursor)
            .flatMap { revisable in
                revision.flatMap { $0 != revisable.word ? (revisable, $0) : nil }
            }
        let autocorrection = autocorrection(in: result, for: currentWord)
        wordTouches.reset()
        lastAutocorrection = nil
        revisableWord = nil
        chosenText = nil

        if autocorrection == nil, separator == " ", currentWord.isEmpty == false,
           keptWords.contains(currentWord.lowercased()) == false {
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
                replacedWords: [currentWord]
            )
            return TextEdit(deleteCount: currentWord.count, insertText: inserted)
        }
        let (previous, replacement) = revised
        let original = previous.word + " " + currentWord
        let inserted = replacement + " " + (autocorrection ?? currentWord) + separator
        lastAutocorrection = AppliedAutocorrection(
            original: original,
            insertedText: inserted,
            replacedWords: autocorrection == nil ? [previous.word] : [previous.word, currentWord]
        )
        return TextEdit(deleteCount: original.count, insertText: inserted)
    }

    /// What backspace does instead of deleting one character, if anything: right after an
    /// autocorrection or revision it restores the typed words and remembers to keep them.
    public func backspaceEdit(textBeforeCursor: String?) -> TextEdit? {
        guard let lastAutocorrection,
              textBeforeCursor?.hasSuffix(lastAutocorrection.insertedText) == true else {
            return nil
        }
        self.lastAutocorrection = nil
        revisableWord = nil
        keptWords.formUnion(lastAutocorrection.replacedWords.map { $0.lowercased() })
        wordTouches.reset()
        return TextEdit(
            deleteCount: lastAutocorrection.insertedText.count,
            insertText: lastAutocorrection.original
        )
    }

    /// What tapping a suggestion-bar item inserts.
    public func choiceEdit(_ item: SuggestionBar.Item, textBeforeCursor: String?) -> TextEdit {
        let context = TypingTextContext(textBeforeCursor: textBeforeCursor)
        lastAutocorrection = nil
        revisableWord = nil
        wordTouches.reset()
        if item.kind == .typed {
            keptWords.insert(context.currentWord.lowercased())
            chosenText = context.currentWord + " "
            return TextEdit(deleteCount: 0, insertText: " ")
        }
        chosenText = item.text + " "
        return TextEdit(deleteCount: context.currentWord.count, insertText: item.text + " ")
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
