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
/// one, such as delete, never waits for suggestions still being worked out.
final class KeyboardPredictionCoordinator {
    var onBarChange: ((SuggestionBar) -> Void)?

    private let session = PredictiveTypingSession()
    private let engine = KeyboardPredictionEngine(label: "org.keyvox.keyboard.prediction", qos: .userInitiated)
    private let tapCheckEngine = KeyboardPredictionEngine(
        label: "org.keyvox.keyboard.prediction.tap-check",
        qos: .userInteractive
    )
    private let textBeforeCursor: () -> String?
    private let selectedText: () -> String?
    private let textAfterCursor: () -> String?
    private let contestedTapPolicy = ContestedTapPolicy()
    private var letterKeys: KeyCenterMap?
    private var latestResult: PredictionResult?
    private var pendingRequest: PredictionRequest?
    /// The newest request read from the text; every change to the text or cursor makes one.
    private var newestRequest: PredictionRequest?
    private var publishedBar = SuggestionBar.empty

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

    init(
        textBeforeCursor: @escaping () -> String?,
        selectedText: @escaping () -> String?,
        textAfterCursor: @escaping () -> String?
    ) {
        self.textBeforeCursor = textBeforeCursor
        self.selectedText = selectedText
        self.textAfterCursor = textAfterCursor
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

    func recordTap(at location: CGPoint) {
        session.recordTap(at: location, textBeforeCursor: textBeforeCursor())
    }

    func textDidChange() {
        session.textDidChange(textBeforeCursor: textBeforeCursor())
    }

    func reset() {
        session.reset()
        latestResult = nil
        engine.queue.async { [weak self] in
            self?.latestRevision = nil
        }
        tapCheckEngine.queue.async { [weak self] in
            self?.latestIntendedLetter = nil
        }
        newestRequest = nil
        publish(.empty)
    }

    func clearBar() {
        newestRequest = nil
        publish(.empty)
    }

    /// Requests suggestions for the text as it is now.
    func refresh(allowsAutocorrection: Bool) {
        let text = textBeforeCursor()
        let request = session.request(
            textBeforeCursor: text,
            selectedText: selectedText(),
            textAfterCursor: textAfterCursor()
        )
        newestRequest = request
        if let latestResult, latestResult.request == request {
            publish(Self.bar(for: latestResult, allowsAutocorrection: allowsAutocorrection))
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
                self.publish(Self.bar(for: result, allowsAutocorrection: allowsAutocorrection))
                if allowsAutocorrection, request.currentWord.isEmpty == false {
                    self.prepareRevision(self.session.revisionRequest(textBeforeCursor: text, result: result))
                }
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

    /// What typing `separator` after the current word inserts, applying any
    /// autocorrection first, and revising the word before it when the current word shows
    /// it was a typo. Punctuation right after a suggestion tap replaces the space the tap
    /// added.
    func wordBoundaryEdit(separator: String, allowsAutocorrection: Bool) -> TextEdit {
        let text = textBeforeCursor()
        let request = session.request(textBeforeCursor: text)
        guard request.currentWord.isEmpty == false,
              allowsAutocorrection,
              let result = currentResult(for: request) else {
            return session.wordBoundaryEdit(separator: separator, textBeforeCursor: text, result: nil)
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

    func backspaceEdit() -> TextEdit? {
        session.backspaceEdit(textBeforeCursor: textBeforeCursor())
    }

    func choiceEdit(_ item: SuggestionBar.Item) -> TextEdit {
        session.choiceEdit(
            item,
            textBeforeCursor: textBeforeCursor(),
            selectedText: selectedText(),
            textAfterCursor: textAfterCursor()
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

    private func publish(_ bar: SuggestionBar) {
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

    // MARK: - Engine queue

    private func compute(_ request: PredictionRequest) -> PredictionResult? {
        try? engine.resolvedComputer()?.compute(request)
    }
}
