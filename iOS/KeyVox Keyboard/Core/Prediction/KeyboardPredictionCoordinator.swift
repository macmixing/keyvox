import Foundation
import KeyVoxPredictiveKeyboard

/// Runs the shared typing session for the keyboard.
///
/// Typing state lives on the main thread; suggestion work runs on a serial background
/// queue and is published only if the text has not changed since it was requested. At a
/// word boundary the current suggestion result is used, or computed on the spot if it
/// has not arrived yet, so a fast space never skips an autocorrection.
final class KeyboardPredictionCoordinator {
    var onBarChange: ((SuggestionBar) -> Void)?

    private let session = PredictiveTypingSession()
    private let queue = DispatchQueue(label: "org.keyvox.keyboard.prediction", qos: .userInitiated)
    private let textBeforeCursor: () -> String?
    private let contestedTapPolicy = ContestedTapPolicy()
    private var letterKeys: KeyCenterMap?
    private var latestResult: PredictionResult?
    private var pendingRequest: PredictionRequest?
    private var publishedBar = SuggestionBar.empty

    // Owned by `queue`.
    private var computer: PredictionComputer?
    private var pendingGeometry: (keys: [PredictionKeyGeometry], size: CGSize)?
    private var pendingVocabulary: PersonalVocabulary?
    private var engineUnavailable = false

    init(textBeforeCursor: @escaping () -> String?) {
        self.textBeforeCursor = textBeforeCursor
    }

    /// Starts loading the engine so the first word does not wait for it.
    func prepare() {
        queue.async { [weak self] in
            _ = self?.resolvedComputer()
        }
    }

    func updateGeometry(_ geometry: [KeyboardCharacterKeyGeometry], keyboardSize: CGSize) {
        let keys = geometry.map { PredictionKeyGeometry(character: $0.character, frame: $0.frame) }
        letterKeys = KeyCenterMap(geometry: keys)
        queue.async { [weak self] in
            guard let self else { return }
            if let computer = self.computer {
                computer.updateKeyboardGeometry(keys, keyboardSize: keyboardSize)
            } else {
                self.pendingGeometry = (keys, keyboardSize)
            }
        }
    }

    func updateVocabulary(_ vocabulary: PersonalVocabulary) {
        latestResult = nil
        queue.async { [weak self] in
            guard let self else { return }
            if let computer = self.computer {
                try? computer.updateVocabulary(vocabulary)
            } else {
                self.pendingVocabulary = vocabulary
            }
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
        publish(.empty)
    }

    func clearBar() {
        publish(.empty)
    }

    /// Requests suggestions for the text as it is now.
    func refresh(allowsAutocorrection: Bool) {
        let request = session.request(textBeforeCursor: textBeforeCursor())
        if let latestResult, latestResult.request == request {
            publish(Self.bar(for: latestResult, allowsAutocorrection: allowsAutocorrection))
            return
        }
        guard request != pendingRequest else { return }
        pendingRequest = request
        queue.async { [weak self] in
            guard let self, let result = self.compute(request) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.pendingRequest == request {
                    self.pendingRequest = nil
                }
                guard self.session.isCurrent(result, textBeforeCursor: self.textBeforeCursor()) else {
                    return
                }
                self.latestResult = result
                self.publish(Self.bar(for: result, allowsAutocorrection: allowsAutocorrection))
            }
        }
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
                queue.sync { try? resolvedComputer()?.revision(for: revisionRequest) }
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
        let maximumDistance = contestedTapPolicy.parameters.maximumDistance
        guard let letterKeys,
              letterKeys.letters(near: location, within: maximumDistance).isEmpty == false else {
            return nil
        }
        let request = session.request(textBeforeCursor: textBeforeCursor())
        return queue.sync {
            try? resolvedComputer()?.intendedLetter(
                forTapAt: location,
                onKeyWithFrame: keyFrame,
                otherKey: otherKey,
                request: request,
                policy: contestedTapPolicy
            )
        }
    }

    func backspaceEdit() -> TextEdit? {
        session.backspaceEdit(textBeforeCursor: textBeforeCursor())
    }

    func choiceEdit(_ item: SuggestionBar.Item) -> TextEdit {
        session.choiceEdit(item, textBeforeCursor: textBeforeCursor())
    }

    private func currentResult(for request: PredictionRequest) -> PredictionResult? {
        if let latestResult, latestResult.request == request {
            return latestResult
        }
        let result = queue.sync { compute(request) }
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

    // MARK: - Queue

    private func compute(_ request: PredictionRequest) -> PredictionResult? {
        try? resolvedComputer()?.compute(request)
    }

    private func resolvedComputer() -> PredictionComputer? {
        if let computer { return computer }
        guard engineUnavailable == false else { return nil }
        guard let engine = try? EnglishPredictiveEngine() else {
            engineUnavailable = true
            return nil
        }
        let computer = PredictionComputer(engine: engine)
        if let pendingGeometry {
            computer.updateKeyboardGeometry(pendingGeometry.keys, keyboardSize: pendingGeometry.size)
            self.pendingGeometry = nil
        }
        if let pendingVocabulary {
            try? computer.updateVocabulary(pendingVocabulary)
            self.pendingVocabulary = nil
        }
        self.computer = computer
        return computer
    }
}
