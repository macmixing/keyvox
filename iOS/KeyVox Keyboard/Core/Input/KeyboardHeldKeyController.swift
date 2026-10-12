import Foundation
import KeyVoxPredictiveKeyboard

/// Opens a held key's popup once the finger has stayed on the key long enough, then follows the
/// finger across the popup's characters.
final class KeyboardHeldKeyController {
    /// How a held key's touch ended.
    enum Outcome: Equatable {
        /// The popup never opened, so the key types as tapped.
        case notOpened
        /// The finger lifted on this character.
        case chose(String)
        /// The finger went far enough below the popup to close it, so nothing types.
        case closed
    }

    /// What a finger's move changed.
    enum Movement: Equatable {
        case unchanged
        case selected(HeldKeyPopupLayout.Cell)
        case closed
    }

    private static let bundledCharacters = try? HeldKeyCharacters.bundled()

    private let holdDuration: TimeInterval
    private var openingTimer: Timer?
    private var opener: (() -> HeldKeyPopupLayout?)?
    private var layout: HeldKeyPopupLayout?
    private var selectedCell: HeldKeyPopupLayout.Cell?
    private var isClosed = false

    init(holdDuration: TimeInterval = KeyboardStyle.heldKeyPopupHoldDuration) {
        self.holdDuration = holdDuration
    }

    /// Whether the popup has opened for the finger, which then picks among its characters
    /// instead of moving to other keys, even once the popup has closed.
    var hasOpened: Bool {
        layout != nil
    }

    /// What holding the key that types `key` offers, or nil for a key holding does nothing on.
    func offer(forKey key: String) -> HeldKeyCharacters.Offer? {
        Self.bundledCharacters?.offer(forKey: key)
    }

    /// Starts timing a finger on a key; `open` shows the popup when the finger has stayed long
    /// enough, returning its layout, or nil when it cannot open.
    func begin(open: @escaping () -> HeldKeyPopupLayout?) {
        cancel()
        opener = open
        let timer = Timer(timeInterval: holdDuration, repeats: false) { [weak self] _ in
            self?.openPopup()
        }
        openingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func update(location: CGPoint) -> Movement {
        guard let layout, isClosed == false else { return .unchanged }
        guard let cell = layout.cell(at: location) else {
            isClosed = true
            return .closed
        }
        guard cell != selectedCell else { return .unchanged }
        selectedCell = cell
        return .selected(cell)
    }

    func end() -> Outcome {
        defer { cancel() }
        if isClosed {
            return .closed
        }
        return selectedCell.map { .chose($0.character) } ?? .notOpened
    }

    func cancel() {
        openingTimer?.invalidate()
        openingTimer = nil
        opener = nil
        layout = nil
        selectedCell = nil
        isClosed = false
    }

    private func openPopup() {
        openingTimer = nil
        layout = opener?()
        opener = nil
        selectedCell = layout?.firstCell
    }
}
