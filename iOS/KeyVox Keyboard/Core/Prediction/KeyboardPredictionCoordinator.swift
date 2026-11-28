import CoreGraphics
import Foundation
import KeyVoxPredictiveKeyboard

/// Runs the shared typing session for the keyboard.
///
/// Typing state lives on the main thread; suggestion work runs on a serial background
/// queue and is published only if no newer request was made while it ran. The text is not
/// read again when the work finishes: by then the system may be replacing the field's
/// document state, and reading it mid-replacement reaches freed memory. At a word boundary
/// the current suggestion result is used, or computed on the spot if it has not arrived
/// yet, so a fast space never skips an autocorrection. The typo check of the word before
/// the current one is worked out in the background after each result in the same way.
/// Checks of taps close to a letter key run on an engine of their own, so a key that needs
/// one, such as delete, never waits for suggestions still being worked out. A swipe is decoded on
/// the suggestion engine's queue; anything typed before its word arrives waits for it first, so
/// words and keys go in the order they were made. A decoded word is checked against where it was
/// swiped without reading the text: the field and the text around the cursor read when the swipe
/// ended, against those read at the last change to the text or cursor and the fields counted since
/// on the main thread. A word whose place moved goes nowhere, so the document is never touched for
/// it; one still in place goes in as the text read when the swipe ended places it. The bar does not
/// change while a swipe is under way; once its word goes in, the bar shows suggestions for that
/// word with no autocorrection, since space ends a word just swiped in as it was swiped.
final class KeyboardPredictionCoordinator {
    var onBarChange: ((SuggestionBar) -> Void)?
    /// The emoji the suggestion bar shows for a word, in the order to show them.
    var emojiForWord: (String) -> [String] = { _ in [] }

    private var session: PredictiveTypingSession
    private var memory: TypingMemory
    private let engine: KeyboardPredictionEngine
    private let tapCheckEngine: KeyboardPredictionEngine
    private let textBeforeCursor: () -> String?
    private let selectedText: () -> String?
    private let textAfterCursor: () -> String?
    private let documentIdentifier: () -> UUID?
    /// Counts the fields the keyboard has typed in, on the main thread.
    private var field = 0
    /// Where a swiped word would go, read at the last change to the text or cursor; nil while the
    /// field's document state is not to be read.
    private var currentPlace: KeyboardSwipePlace?
    /// Where a swiped word would go right after the word just swiped in went in; the cursor or the
    /// field moving from there ends that word's record.
    private var placeAfterSwipedWord: KeyboardSwipePlace?
    private let contestedTapPolicy = ContestedTapPolicy()
    private var letterKeys: KeyCenterMap?
    private var latestResult: PredictionResult?
    private var pendingRequest: PredictionRequest?
    /// The newest request read from the text; every change to the text or cursor makes one.
    private var newestRequest: PredictionRequest?
    private var barWithoutEmoji = SuggestionBar.empty
    private var barRequest: PredictionRequest?
    private var newestEmojiWord: String?
    private var publishedBar = SuggestionBar.empty
    /// The swipe being decoded and where it ended, which `finishPendingSwipe` hands over at once
    /// when something else is typed before it arrives.
    private var pendingSwipe: (number: Int, place: KeyboardSwipePlace, deliver: (TextEdit) -> Void)?
    private var swipeNumber = 0
    // Owned by `engine.queue`.
    /// Decoded swipes not yet handed over, by number.
    private var decodedSwipes: [Int: String?] = [:]

    // Owned by `engine.queue`.
    /// The newest typo check of the word before the current one, worked out ahead of the
    /// word boundary that needs it.
    private var latestRevision: (request: RevisionRequest, revision: String?)?
    // Owned by `tapCheckEngine.queue`.
    /// The newest check of a tap close to a letter key, worked out when the finger landed.
    private var latestIntendedLetter: (check: ContestedTapCheck, letter: Character?)?

    /// A tap close to a letter key and the text it landed in; the same check gets the same
    /// answer.
    private struct ContestedTapCheck: Equatable {
        let location: CGPoint
        let keyFrame: CGRect
        let otherKey: ContestedTap.OtherKey
        let request: PredictionRequest
    }

    /// - Parameter memory: What the keyboard learned from the user's typing, shared with every
    ///   field's session while the keyboard runs.
    init(
        memory: TypingMemory,
        textBeforeCursor: @escaping () -> String?,
        selectedText: @escaping () -> String?,
        textAfterCursor: @escaping () -> String?,
        documentIdentifier: @escaping () -> UUID?
    ) {
        let language = KeyboardTypingLanguage.current
        session = PredictiveTypingSession(language: language, memory: memory)
        self.memory = memory
        engine = KeyboardPredictionEngine(language: language, label: "org.keyvox.keyboard.prediction", qos: .userInitiated)
        tapCheckEngine = KeyboardPredictionEngine(
            language: language,
            label: "org.keyvox.keyboard.prediction.tap-check",
            qos: .userInteractive
        )
        self.textBeforeCursor = textBeforeCursor
        self.selectedText = selectedText
        self.textAfterCursor = textAfterCursor
        self.documentIdentifier = documentIdentifier
    }

    /// Types in `language` from now on, learning into `memory`, its own memory, without reading the
    /// field: the swipe being decoded is dropped, the typing session starts over in the new
    /// language, the bar empties, and both engines let go of the previous language's files, loading
    /// the new one's when next needed. The user's vocabulary carries over; the new language's
    /// learned words come through `updateLearnedWords(_:)`.
    func setLanguage(_ language: TypingLanguage, memory: TypingMemory) {
        dropPendingSwipe()
        self.memory = memory
        session = PredictiveTypingSession(language: language, memory: memory)
        placeAfterSwipedWord = nil
        letterKeys = nil
        latestResult = nil
        clearBar()
        engine.queue.async { [weak self] in
            guard let self else { return }
            self.latestRevision = nil
            self.decodedSwipes.removeAll()
            self.engine.setLanguage(language)
        }
        tapCheckEngine.queue.async { [weak self] in
            guard let self else { return }
            self.latestIntendedLetter = nil
            self.tapCheckEngine.setLanguage(language)
        }
    }

    /// Starts loading the engines so the first word does not wait for them.
    func prepare() {
        for engine in [engine, tapCheckEngine] {
            engine.queue.async {
                _ = engine.resolvedComputer()
            }
        }
    }

    func updateGeometry(_ geometry: [KeyboardCharacterKeyGeometry], keyboardSize: CGSize) {
        let keys = geometry.map { PredictionKeyGeometry(character: $0.character, frame: $0.frame) }
        letterKeys = KeyCenterMap(geometry: keys)
        engine.queue.async { [engine] in
            engine.updateKeyboardGeometry(keys, keyboardSize: keyboardSize)
        }
        tapCheckEngine.queue.async { [weak self] in
            guard let self else { return }
            self.latestIntendedLetter = nil
            self.tapCheckEngine.updateKeyboardGeometry(keys, keyboardSize: keyboardSize)
        }
    }

    func updateVocabulary(_ vocabulary: PersonalVocabulary) {
        latestResult = nil
        engine.queue.async { [weak self] in
            guard let self else { return }
            self.latestRevision = nil
            self.engine.updateVocabulary(vocabulary)
        }
        tapCheckEngine.queue.async { [weak self] in
            guard let self else { return }
            self.latestIntendedLetter = nil
            self.tapCheckEngine.updateVocabulary(vocabulary)
        }
    }

    /// Call whenever what the keyboard learned from the user's typing changes. Only suggestions
    /// use it; a tap close to a letter key is judged by dictionary and personal words alone.
    func updateLearnedWords(_ learned: LearnedVocabulary) {
        latestResult = nil
        engine.queue.async { [weak self] in
            guard let self else { return }
            self.latestRevision = nil
            self.engine.updateLearnedWords(learned)
        }
    }

    func recordTap(at location: CGPoint) {
        session.recordTap(at: location, textBeforeCursor: textBeforeCursor())
    }

    func textDidChange() {
        session.textDidChange(textBeforeCursor: textBeforeCursor(), textAfterCursor: textAfterCursor())
        if currentPlace != nil {
            currentPlace = readPlace()
        }
        endSwipedWordIfMoved()
    }

    /// Reads where a swiped word would go again after the keyboard's own edit.
    func textWasEdited() {
        if currentPlace != nil {
            currentPlace = readPlace()
        }
        endSwipedWordIfMoved()
    }

    /// Ends the record of the word just swiped in once the cursor or the field has moved from where
    /// that word left it, even when the text before the cursor still ends with the word.
    private func endSwipedWordIfMoved() {
        guard let placeAfterSwipedWord, currentPlace != placeAfterSwipedWord else { return }
        self.placeAfterSwipedWord = nil
        session.forgetSwipedWord()
    }

    /// Starts typing in the focused field, which counts as a new one.
    func reset() {
        field += 1
        currentPlace = readPlace()
        placeAfterSwipedWord = nil
        session.reset()
        latestResult = nil
        engine.queue.async { [weak self] in
            self?.latestRevision = nil
        }
        tapCheckEngine.queue.async { [weak self] in
            self?.latestIntendedLetter = nil
        }
        clearBar()
    }

    func clearBar() {
        newestRequest = nil
        newestEmojiWord = nil
        publish(.empty, for: nil)
    }

    /// Requests suggestions for the text as it is now. The bar offers no autocorrection for a word
    /// just swiped in, which space ends as it was swiped.
    func refresh(allowsAutocorrection: Bool) {
        let text = textBeforeCursor()
        let selected = selectedText()
        let after = textAfterCursor()
        let allowsAutocorrection = allowsAutocorrection && session.endsWithSwipedWord(textBeforeCursor: text) == false
        let request = session.request(textBeforeCursor: text, selectedText: selected, textAfterCursor: after)
        newestEmojiWord = session.emojiWord(textBeforeCursor: text, selectedText: selected, textAfterCursor: after)
        newestRequest = request
        if let latestResult, latestResult.request == request {
            publish(Self.bar(for: latestResult, allowsAutocorrection: allowsAutocorrection), for: request)
            return
        }
        guard request != pendingRequest else { return }
        pendingRequest = request
        engine.queue.async { [weak self] in
            guard let self, let result = self.compute(request) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.pendingRequest == request {
                    self.pendingRequest = nil
                }
                guard self.newestRequest == request else { return }
                self.latestResult = result
                self.publish(Self.bar(for: result, allowsAutocorrection: allowsAutocorrection), for: request)
                if allowsAutocorrection, request.currentWord.isEmpty == false {
                    self.prepareRevision(self.session.revisionRequest(textBeforeCursor: text, result: result))
                }
            }
        }
    }

    /// Works out on the engine's queue what the typing language's accent key shows after `text`,
    /// choosing by the dictionary's words, and hands it to `deliver` on the main thread; the caller
    /// checks that its text is still that.
    func accentKeyMark(after text: String?, deliver: @escaping (String) -> Void) {
        engine.queue.async { [weak self] in
            guard let self, let mark = self.engine.resolvedComputer()?.accentKeyMark(after: text) else { return }
            DispatchQueue.main.async {
                deliver(mark)
            }
        }
    }

    /// Works out the typo check of the word before the current one in the background, so
    /// the word boundary that needs it does not wait for it.
    private func prepareRevision(_ request: RevisionRequest?) {
        guard let request else { return }
        engine.queue.async { [weak self] in
            guard let self, self.latestRevision?.request != request else { return }
            _ = self.resolvedRevision(for: request)
        }
    }

    /// The typo check for `request`: the one already worked out when it matches, otherwise
    /// worked out now. Runs on `engine.queue`.
    private func resolvedRevision(for request: RevisionRequest) -> String? {
        if let latestRevision, latestRevision.request == request {
            return latestRevision.revision
        }
        let revision = try? engine.resolvedComputer()?.revision(for: request)
        latestRevision = (request, revision)
        return revision
    }

    /// What typing `character`, one that does not end a word, does right after a suggestion tap
    /// when it takes the place of the space the tap added; nil when it follows the space.
    func pickedWordSpaceEdit(character: String, typesExactly: Bool) -> TextEdit? {
        session.pickedWordSpaceEdit(character: character, typesExactly: typesExactly, textBeforeCursor: textBeforeCursor())
    }

    /// What tapping `letter` right after a word just swiped in does: a space, then the letter;
    /// nil when no swiped word ends right before the cursor or the swipe put a space after it.
    func swipedWordLetterEdit(letter: String) -> TextEdit? {
        session.swipedWordLetterEdit(letter: letter, textBeforeCursor: textBeforeCursor())
    }

    /// What typing `separator` after the current word inserts, applying any
    /// autocorrection first, and revising the word before it when the current word shows
    /// it was a typo. A separator that takes the place of a suggestion tap's space, right after
    /// the tap, replaces that space. A word just swiped in ends as it was swiped, waiting for nothing.
    func wordBoundaryEdit(separator: String, allowsAutocorrection: Bool) -> TextEdit {
        let text = textBeforeCursor()
        let request = session.request(textBeforeCursor: text)
        guard request.currentWord.isEmpty == false,
              session.endsWithSwipedWord(textBeforeCursor: text) == false else {
            return session.wordBoundaryEdit(separator: separator, textBeforeCursor: text, result: nil)
        }
        guard allowsAutocorrection, let result = currentResult(for: request) else {
            // Without autocorrection space waits for nothing; the suggestions already worked
            // out only tell whether the word counts toward learning it.
            return session.wordBoundaryEdit(
                separator: separator,
                textBeforeCursor: text,
                result: latestResult?.request == request ? latestResult : nil,
                allowsAutocorrection: false
            )
        }
        let revision = session.revisionRequest(textBeforeCursor: text, result: result)
            .flatMap { revisionRequest in
                engine.queue.sync { resolvedRevision(for: revisionRequest) }
            }
        return session.wordBoundaryEdit(
            separator: separator,
            textBeforeCursor: text,
            result: result,
            revision: revision
        )
    }

    /// The edit the keyboard applies itself when `separator` ends the current word: an
    /// autocorrection, or the separator ending a word just swiped in, which goes in as it is so the
    /// first space after a swiped word never types the double-space period; nil when the key's
    /// regular path types the separator.
    func appliedWordBoundaryEdit(separator: String, allowsAutocorrection: Bool) -> TextEdit? {
        let endsSwipedWord = session.endsWithSwipedWord(textBeforeCursor: textBeforeCursor())
        let edit = wordBoundaryEdit(separator: separator, allowsAutocorrection: allowsAutocorrection)
        return edit.deleteCount > 0 || endsSwipedWord ? edit : nil
    }

    /// The letter a tap on another key was meant for, or nil to keep that key. Only taps
    /// close to a letter key wait for the engine.
    func intendedLetter(
        forTapAt location: CGPoint,
        onKeyWithFrame keyFrame: CGRect,
        otherKey: ContestedTap.OtherKey
    ) -> Character? {
        guard let check = contestedTapCheck(at: location, onKeyWithFrame: keyFrame, otherKey: otherKey) else {
            return nil
        }
        return tapCheckEngine.queue.sync { resolvedIntendedLetter(for: check) }
    }

    /// Starts working out `intendedLetter` for a finger that just landed, so the answer is
    /// usually ready when it lifts.
    func prepareIntendedLetter(
        forTapAt location: CGPoint,
        onKeyWithFrame keyFrame: CGRect,
        otherKey: ContestedTap.OtherKey
    ) {
        guard let check = contestedTapCheck(at: location, onKeyWithFrame: keyFrame, otherKey: otherKey) else {
            return
        }
        tapCheckEngine.queue.async { [weak self] in
            _ = self?.resolvedIntendedLetter(for: check)
        }
    }

    /// The tap and text a tap close to a letter key is checked against, or nil when no letter
    /// key is close enough for the tap to be meant for it.
    private func contestedTapCheck(
        at location: CGPoint,
        onKeyWithFrame keyFrame: CGRect,
        otherKey: ContestedTap.OtherKey
    ) -> ContestedTapCheck? {
        guard let letterKeys,
              letterKeys.letters(
                  near: location,
                  within: contestedTapPolicy.maximumDistance(for: otherKey)
              ).isEmpty == false else {
            return nil
        }
        let request = session.request(textBeforeCursor: textBeforeCursor())
        guard contestedTapPolicy.keepsOtherKey(
            otherKey,
            startsWord: request.currentWord.isEmpty,
            landedOnOtherKey: keyFrame.contains(location)
        ) == false else {
            return nil
        }
        return ContestedTapCheck(location: location, keyFrame: keyFrame, otherKey: otherKey, request: request)
    }

    /// The letter `check` was meant for: the answer already worked out when it matches,
    /// otherwise worked out now. Runs on `tapCheckEngine.queue`.
    private func resolvedIntendedLetter(for check: ContestedTapCheck) -> Character? {
        if let latestIntendedLetter, latestIntendedLetter.check == check {
            return latestIntendedLetter.letter
        }
        let letter = try? tapCheckEngine.resolvedComputer()?.intendedLetter(
            forTapAt: check.location,
            onKeyWithFrame: check.keyFrame,
            otherKey: check.otherKey,
            request: check.request,
            policy: contestedTapPolicy
        )
        latestIntendedLetter = (check, letter)
        return letter
    }

    /// What tapping `item` inserts. Tapping the typed word while the bar shows a correction
    /// turns that correction down; `allowsAutocorrection` says whether the field lets the bar show
    /// one, which it never does for a word just swiped in.
    func choiceEdit(_ item: SuggestionBar.Item, allowsAutocorrection: Bool) -> TextEdit {
        let text = textBeforeCursor()
        let selected = selectedText()
        let after = textAfterCursor()
        let allowsAutocorrection = allowsAutocorrection && session.endsWithSwipedWord(textBeforeCursor: text) == false
        let request = session.request(textBeforeCursor: text, selectedText: selected, textAfterCursor: after)
        return session.choiceEdit(
            item,
            textBeforeCursor: text,
            selectedText: selected,
            textAfterCursor: after,
            result: latestResult?.request == request ? latestResult : nil,
            allowsAutocorrection: allowsAutocorrection
        )
    }

    private func currentResult(for request: PredictionRequest) -> PredictionResult? {
        if let latestResult, latestResult.request == request {
            return latestResult
        }
        let result = engine.queue.sync { compute(request) }
        if let result {
            latestResult = result
        }
        return result
    }

    private func publish(_ bar: SuggestionBar, for request: PredictionRequest?) {
        barWithoutEmoji = bar
        barRequest = request
        refreshEmojiSuggestions()
    }

    // The emoji index finishes asynchronously, when the host may be replacing the document.
    func refreshEmojiSuggestions() {
        guard barRequest == newestRequest else { return }
        let bar = barWithoutEmoji.showing(emoji: newestEmojiWord.map(emojiForWord) ?? [])
        guard bar != publishedBar else { return }
        publishedBar = bar
        onBarChange?(bar)
    }

    private static func bar(for result: PredictionResult, allowsAutocorrection: Bool) -> SuggestionBar {
        guard allowsAutocorrection == false, let primary = result.bar.primary,
              primary.kind == .autocorrection else {
            return result.bar
        }
        return SuggestionBar(
            primary: SuggestionBar.Item(text: primary.text, kind: .suggestion),
            leading: result.bar.leading,
            trailing: result.bar.trailing
        )
    }

    /// Decodes a swipe's path off the main thread and hands the edit typing the word it was swiped
    /// as to `deliver` on the main thread, unless `finishPendingSwipe` handed it over first.
    /// Nothing is handed over for a swipe decoded as no word, whose place has changed by then
    /// (`KeyboardSwipePlace`), or that was dropped (`dropPendingSwipe`).
    func decodeSwipe(_ path: [SwipeTouchSample], wordCase: SwipeWordCase, deliver: @escaping (TextEdit) -> Void) {
        finishPendingSwipe()
        guard let place = recordSwipePlace() else { return }
        swipeNumber += 1
        let number = swipeNumber
        let previousWords = session.previousWords(beforeSwipeAfter: place.textBeforeCursor, selectedText: place.selectedText)
        pendingSwipe = (number, place, deliver)
        engine.queue.async { [weak self] in
            guard let self else { return }
            let word = (try? self.engine.resolvedComputer()?.swipeWords(
                for: path,
                previousWords: previousWords,
                wordCase: wordCase,
                limit: 1
            ))?.first
            self.decodedSwipes[number] = word
            DispatchQueue.main.async { [weak self] in
                self?.handOverSwipe(number)
            }
        }
    }

    /// Hands over the swipe being decoded now, waiting for it, so what is typed next follows its
    /// word.
    func finishPendingSwipe() {
        guard let pending = pendingSwipe else { return }
        handOverSwipe(pending.number)
    }

    /// Forgets the swipe being decoded, whose word then goes nowhere, as when another field takes
    /// the keyboard.
    func dropPendingSwipe() {
        guard let pending = pendingSwipe else { return }
        pendingSwipe = nil
        engine.queue.async { [weak self] in
            self?.decodedSwipes[pending.number] = nil
        }
    }

    /// Stops reading the field until `reset` starts the next one, and drops the swipe being decoded,
    /// as when the keyboard appears or goes away: the host may be replacing the field's document
    /// state, which a read then can find freed.
    func leaveField() {
        field += 1
        currentPlace = nil
        placeAfterSwipedWord = nil
        session.forgetSwipedWord()
        dropPendingSwipe()
    }

    /// Where a swiped word would go, as read at the last change to the text or cursor.
    var swipePlace: KeyboardSwipePlace? { currentPlace }

    /// Reads where a swiped word would go now, as a swipe ends; nil while the field is not to be read.
    func recordSwipePlace() -> KeyboardSwipePlace? {
        guard currentPlace != nil else { return nil }
        currentPlace = readPlace()
        endSwipedWordIfMoved()
        return currentPlace
    }

    private func readPlace() -> KeyboardSwipePlace {
        KeyboardSwipePlace(
            field: field,
            document: documentIdentifier(),
            textBeforeCursor: textBeforeCursor(),
            selectedText: selectedText(),
            textAfterCursor: textAfterCursor()
        )
    }

    /// Whether letters of a word the user typed come right before the cursor; a word just swiped in
    /// is not one, since the next swiped word goes in after a space instead.
    func hasTypedWordInProgress() -> Bool {
        let text = textBeforeCursor()
        return session.request(textBeforeCursor: text).currentWord.isEmpty == false
            && session.endsWithSwipedWord(textBeforeCursor: text) == false
    }

    private func handOverSwipe(_ number: Int) {
        guard let pending = pendingSwipe, pending.number == number else { return }
        let word = engine.queue.sync { decodedSwipes.removeValue(forKey: number) } ?? nil
        pendingSwipe = nil
        // The cursor or the field moved since the swipe ended, so its word has nowhere to go; the
        // check reads only what the main thread recorded, never the document.
        guard let word, currentPlace == pending.place else { return }
        let edit = session.swipeEdit(
            word: word,
            textBeforeCursor: pending.place.textBeforeCursor,
            selectedText: pending.place.selectedText,
            textAfterCursor: pending.place.textAfterCursor
        )
        placeAfterSwipedWord = nil
        pending.deliver(edit)
        placeAfterSwipedWord = currentPlace
    }

    // MARK: - Engine queue

    private func compute(_ request: PredictionRequest) -> PredictionResult? {
        try? engine.resolvedComputer()?.compute(request)
    }
}
