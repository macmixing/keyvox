import Foundation

/// Where a swiped word goes: the field, and the text around the cursor when the swipe ended. A word
/// whose place has changed by the time it would go in, because the cursor moved or another field
/// took the keyboard, goes nowhere rather than somewhere the user did not swipe it.
struct KeyboardSwipePlace: Equatable {
    /// Which of the fields the keyboard has typed in since it started this is, counted on the
    /// main thread.
    let field: Int
    /// The host's identifier for the field's document.
    let document: UUID?
    let textBeforeCursor: String?
    let selectedText: String?
    let textAfterCursor: String?
}
