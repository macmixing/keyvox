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
        /// Where the replacement sits in the edit's corrected words.
        let range: Range<Int>
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

    /// The text before a watched spot: its last `watchedContext` characters, which tell where the
    /// spot is, and how long all of it is.
    private struct PrecedingText {
        let suffix: String
        let count: Int

        init(_ text: String) {
            suffix = String(text.suffix(PredictiveTypingSession.watchedContext))
            count = text.count
        }

        var isWhole: Bool { suffix.count == count }

        /// Whether the user deleted on past the spot into this text, as a held delete does a word
        /// at a time.
        func isDeletedPast(in text: String) -> Bool {
            let deleted = count - text.count
            return deleted > 0 && deleted < suffix.count && text.hasSuffix(suffix.dropLast(deleted))
        }
    }

    /// A recent autocorrection the user may delete back to, as the system keyboard watches it
    /// (measured with `Tools/AppleKeyboardBaseline`): deleting into a word it changed, or past it,
    /// even after typing on, holds that change back while the keyboard runs, for the word typed
    /// in the same capitals, except the capital of the pronoun "I".
    private struct WatchedCorrection {
        /// The text before the corrected words.
        let precedingText: PrecedingText
        let insertedText: String
        /// The changes not deleted into yet.
        var corrections: [Correction]

        /// How many characters of what the autocorrection inserted `text` still ends with, when
        /// the user deleted back into them.
        func keptCount(in text: String) -> Int? {
            (0...insertedText.count).reversed().first { count in
                let kept = precedingText.suffix + insertedText.prefix(count)
                return precedingText.isWhole ? text == kept : text.hasSuffix(kept)
            }
        }
    }

    /// A word typed in place of changes the user deleted into, as the system keyboard watches it:
    /// deleting on past its start lets those changes apply again, while deleting back only to its
    /// start or into it does not.
    private struct ReplacementWord {
        /// The text before the word.
        let precedingText: PrecedingText
        let corrections: [Correction]
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
    private static let watchedContext = 24
    /// How many recent autocorrections, and words typed in place of them, are watched; older ones
    /// drop off.
    private static let watchedCorrectionsLimit = 20

    private var wordTouches = TypedWordTouches()
    private var lastAutocorrection: AppliedAutocorrection?
    /// The last autocorrection once the user deleted the separator after it, which the suggestion
    /// bar offers to undo while the text still ends with the corrected words.
    private var revertibleAutocorrection: AppliedAutocorrection?
    private var revisableWord: RevisableWord?
    private var watchedCorrections: [WatchedCorrection] = []
    private var replacementWords: [ReplacementWord] = []
    /// How long the text before the cursor was when last told, which tells a deletion.
    private var lastTextCount = 0
    /// Once the user deleted into or past a word the keyboard changed, the text before the word at
    /// the cursor, or its last `watchedContext` characters: the word typed there next, unless the
    /// text is emptied first, takes the change's place, and keeps as typed, at its space and when
    /// the next word follows, when it is a slip from the change, as on the system keyboard.
    private var textBeforeReplacedWord: String?
    /// The changes the user deleted into that the word typed next takes the place of.
    private var replacedCorrections: [Correction] = []
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
        let text = textBeforeCursor ?? ""
        // Only a deletion reaches back into a change; emptying the text, as clearing it or
        // deleting all of it does, turns nothing down and ends the watch on what it held.
        if text.isEmpty {
            watchedCorrections = []
            replacementWords = []
            textBeforeReplacedWord = nil
            replacedCorrections = []
        } else if text.count < lastTextCount {
            watchDeletion(textBeforeCursor: text)
        }
        lastTextCount = text.count
        wordTouches.synchronize(currentWord: TypingTextContext(textBeforeCursor: textBeforeCursor).currentWord)
    }

    /// Lets changes apply again once the user deletes on past the word typed in their place
    /// (`ReplacementWord`), holds back each change of a recent autocorrection the user deleted
    /// into or past (`WatchedCorrection`), and from then on marks where the word typed next starts.
    private func watchDeletion(textBeforeCursor text: String) {
        for replacement in replacementWords where replacement.precedingText.isDeletedPast(in: text) {
            for correction in replacement.corrections {
                memory.withdrawDeletion(of: correction.correction, typed: correction.typed)
            }
        }
        replacementWords.removeAll { $0.precedingText.isDeletedPast(in: text) }

        var reachedAny = false
        for index in watchedCorrections.indices {
            var watched = watchedCorrections[index]
            guard let kept = watched.keptCount(in: text) ?? (watched.precedingText.isDeletedPast(in: text) ? 0 : nil) else {
                continue
            }
            let deletedInto = watched.corrections.filter { kept < $0.range.upperBound }
            guard deletedInto.isEmpty == false else { continue }
            watched.corrections.removeAll { kept < $0.range.upperBound }
            watchedCorrections[index] = watched
            for correction in deletedInto where WordCasing.capitalizingPronoun(correction.typed) != correction.correction {
                memory.recordDeletion(of: correction.correction, typed: correction.typed)
            }
            replacedCorrections += deletedInto
            reachedAny = true
        }
        watchedCorrections.removeAll { $0.corrections.isEmpty }
        if reachedAny || textBeforeReplacedWord != nil {
            let currentWord = TypingTextContext(textBeforeCursor: text).currentWord
            textBeforeReplacedWord = String(text.dropLast(currentWord.count).suffix(Self.watchedContext))
        }
    }

    /// Call when the field changes or the keyboard reappears.
    public func reset() {
        wordTouches.reset()
        lastAutocorrection = nil
        revertibleAutocorrection = nil
        revisableWord = nil
        watchedCorrections = []
        replacementWords = []
        lastTextCount = 0
        textBeforeReplacedWord = nil
        replacedCorrections = []
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

    /// The word the suggestion bar's emoji are for, as on the system keyboard: the word typed right
    /// before the cursor, or the last word before it when only spaces and punctuation follow it,
    /// as "pizza " and "dog. " leave it; nil inside a word, with text selected, and while the bar
    /// offers to put back a correction.
    public func emojiWord(textBeforeCursor: String?, selectedText: String? = nil, textAfterCursor: String? = nil) -> String? {
        guard selectedText?.isEmpty ?? true, revertibleAutocorrection(endingAt: textBeforeCursor) == nil else {
            return nil
        }
        let context = TypingTextContext(textBeforeCursor: textBeforeCursor, textAfterCursor: textAfterCursor)
        guard context.currentWord.isEmpty == false else { return context.wordBeforeSeparators }
        return context.restOfWord.isEmpty ? context.currentWord : nil
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
    /// then offers to put back what was typed (see `choiceEdit`); deleting into a word it changed
    /// holds that change back while the keyboard runs, and a word typed in its place that is a slip
    /// from it keeps as typed (`WatchedCorrection`). Punctuation right after a
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
        let isTypedInPlace = currentWord.isEmpty == false
            && textBeforeReplacedWord.map { textBeforeCursor?.hasSuffix($0 + currentWord) == true } == true
        // The word typed in place of a change keeps as typed when it is a slip from what was typed
        // there or from the change, and its own correction is held back like one deleted into;
        // any other word is corrected as usual, as on the system keyboard.
        let replacesDeletedChange = isTypedInPlace && replacedCorrections.contains { replaced in
            TypingSlip.isAtMostOne(between: currentWord, and: replaced.typed)
                || TypingSlip.isAtMostOne(between: currentWord, and: replaced.correction)
        }
        let turnedDown = replacesDeletedChange
            ? self.autocorrection(in: result, for: currentWord)
                .flatMap { WordCasing.capitalizingPronoun(currentWord) == $0 ? nil : $0 }
                .map { Correction(typed: currentWord, correction: $0, range: 0..<$0.count) }
            : nil
        let autocorrection = allowsAutocorrection && replacesDeletedChange == false
            ? autocorrection(in: result, for: currentWord)
            : nil
        if let turnedDown {
            memory.recordUndo(of: turnedDown.correction, typed: turnedDown.typed)
        }
        if isTypedInPlace {
            replacementWords.append(ReplacementWord(
                precedingText: PrecedingText(String((textBeforeCursor ?? "").dropLast(currentWord.count))),
                corrections: replacedCorrections + (turnedDown.map { [$0] } ?? [])
            ))
            if replacementWords.count > Self.watchedCorrectionsLimit {
                replacementWords.removeFirst(replacementWords.count - Self.watchedCorrectionsLimit)
            }
        }
        textBeforeReplacedWord = nil
        replacedCorrections = []
        wordTouches.reset()
        lastAutocorrection = nil
        revertibleAutocorrection = nil
        revisableWord = nil
        chosenText = nil

        // A word kept only because the user deleted into a change of it, there or before, teaches
        // nothing, as on the system keyboard, and that change is held back for it in any capitals
        // from then on.
        let keptForTurnedDownChange = replacesDeletedChange || memory.rejections.hasUndone(currentWord)
        if autocorrection == nil, keptForTurnedDownChange {
            memory.recordKeep(of: currentWord)
        } else if autocorrection == nil {
            recordKeptWord(currentWord, result: result)
        } else if let autocorrection, autocorrection.lowercased() == currentWord.lowercased(),
                  result?.typedWordKind == .unknown {
            // A learned word given the user's capitals is still a use of it.
            recordKeptWord(currentWord, writtenAs: autocorrection, result: result)
        }
        // A word the user turned a correction of down, or typed in place of a change they
        // deleted into, is not revised by the word after it.
        if autocorrection == nil, separator == " ", currentWord.isEmpty == false, replacesDeletedChange == false,
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
                corrections: [Correction(typed: currentWord, correction: autocorrection, range: 0..<autocorrection.count)]
            )
            lastAutocorrection = applied
            watchDeletion(from: applied, textBefore: String((textBeforeCursor ?? "").dropLast(currentWord.count)))
            return TextEdit(deleteCount: currentWord.count, insertText: applied.insertedText)
        }
        let (previous, replacement) = revised
        let original = previous.word + " " + currentWord
        let correctedText = replacement + " " + (autocorrection ?? currentWord)
        let applied = AppliedAutocorrection(
            original: original,
            correctedText: correctedText,
            separator: separator,
            corrections: [Correction(typed: previous.word, correction: replacement, range: 0..<replacement.count)]
                + (autocorrection.map {
                    [Correction(typed: currentWord, correction: $0, range: (replacement.count + 1)..<correctedText.count)]
                } ?? [])
        )
        lastAutocorrection = applied
        watchDeletion(from: applied, textBefore: String((textBeforeCursor ?? "").dropLast(original.count)))
        return TextEdit(deleteCount: original.count, insertText: applied.insertedText)
    }

    /// Watches for the user deleting back into `applied`, which follows `textBefore`
    /// (`WatchedCorrection`).
    private func watchDeletion(from applied: AppliedAutocorrection, textBefore: String) {
        watchedCorrections.append(WatchedCorrection(
            precedingText: PrecedingText(textBefore),
            insertedText: applied.insertedText,
            corrections: applied.corrections
        ))
        if watchedCorrections.count > Self.watchedCorrectionsLimit {
            watchedCorrections.removeFirst(watchedCorrections.count - Self.watchedCorrectionsLimit)
        }
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
        // space, as on the system keyboard; the next tap picks. An emoji, offered for the word
        // before the mark, is spaced away and typed in one tap.
        let isAfterSpacedMark = word.text.isEmpty && textBeforeCursor?.last.map {
            Self.spacedFromPickedWordCharacters?.contains(String($0)) == true
        } == true
        if isAfterSpacedMark, item.kind != .emoji {
            return TextEdit(deleteCount: 0, insertText: " ")
        }
        let leadingSpace = isAfterSpacedMark ? " " : ""
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
            insertText: leadingSpace + written + space,
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
