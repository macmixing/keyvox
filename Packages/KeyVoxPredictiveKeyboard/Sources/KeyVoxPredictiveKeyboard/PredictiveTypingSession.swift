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
        let original: String
        let insertedText: String
    }

    private var wordTouches = TypedWordTouches()
    private var lastAutocorrection: AppliedAutocorrection?
    /// Words whose autocorrection the user undid; space keeps them as typed.
    private var keptWords: Set<String> = []

    public init() {}

    /// Call after a tapped character has been inserted.
    public func recordTap(at location: CGPoint, textBeforeCursor: String?) {
        lastAutocorrection = nil
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
        wordTouches.synchronize(currentWord: TypingTextContext(textBeforeCursor: textBeforeCursor).currentWord)
    }

    /// Call when the field changes or the keyboard reappears.
    public func reset() {
        wordTouches.reset()
        lastAutocorrection = nil
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

    /// What space inserts. `result` must be current for `textBeforeCursor`.
    public func spaceEdit(textBeforeCursor: String?, result: PredictionResult) -> TextEdit {
        let currentWord = result.request.currentWord
        wordTouches.reset()
        guard let replacement = result.autocorrection, replacement != currentWord else {
            lastAutocorrection = nil
            return TextEdit(deleteCount: 0, insertText: " ")
        }
        let inserted = replacement + " "
        lastAutocorrection = AppliedAutocorrection(original: currentWord, insertedText: inserted)
        return TextEdit(deleteCount: currentWord.count, insertText: inserted)
    }

    /// What backspace does instead of deleting one character, if anything: right after an
    /// autocorrection it restores the typed word and remembers to keep it.
    public func backspaceEdit(textBeforeCursor: String?) -> TextEdit? {
        guard let lastAutocorrection,
              textBeforeCursor?.hasSuffix(lastAutocorrection.insertedText) == true else {
            return nil
        }
        self.lastAutocorrection = nil
        keptWords.insert(lastAutocorrection.original.lowercased())
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
        wordTouches.reset()
        if item.kind == .typed {
            keptWords.insert(context.currentWord.lowercased())
            return TextEdit(deleteCount: 0, insertText: " ")
        }
        return TextEdit(deleteCount: context.currentWord.count, insertText: item.text + " ")
    }
}
