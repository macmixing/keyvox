import CoreGraphics
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
    private var opener: (() -> (layout: HeldKeyPopupLayout, fingerLocation: CGPoint)?)?
    private var followsMovement = false
    private var layout: HeldKeyPopupLayout?
    /// How far across the finger is read from where it is, so that it starts on the first cell
    /// when the selection follows its movement.
    private var selectionOffset: CGFloat = 0
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
    /// enough, returning its layout and where the finger is in it, or nil when it cannot open.
    /// - Parameter followsMovement: Whether the selection moves as the finger moves from where it
    ///   was when the popup opened, rather than to the cell under the finger, as the system
    ///   keyboard's web endings popup does: it may open beside the key, its first ending still
    ///   selected until the finger slides.
    func begin(
        followsMovement: Bool = false,
        open: @escaping () -> (layout: HeldKeyPopupLayout, fingerLocation: CGPoint)?
    ) {
        cancel()
        opener = open
        self.followsMovement = followsMovement
        let timer = Timer(timeInterval: holdDuration, repeats: false) { [weak self] _ in
            self?.openPopup()
        }
        openingTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    func update(location: CGPoint) -> Movement {
        guard let layout, isClosed == false else { return .unchanged }
        guard let cell = layout.cell(at: CGPoint(x: location.x + selectionOffset, y: location.y)) else {
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
        followsMovement = false
        layout = nil
        selectionOffset = 0
        selectedCell = nil
        isClosed = false
    }

    private func openPopup() {
        openingTimer = nil
        let opened = opener?()
        opener = nil
        layout = opened?.layout
        selectedCell = layout?.firstCell
        if let opened, followsMovement {
            selectionOffset = opened.layout.firstCell.frame.midX - opened.fingerLocation.x
        }
    }
}
