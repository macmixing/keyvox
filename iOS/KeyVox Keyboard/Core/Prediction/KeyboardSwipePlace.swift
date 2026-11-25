/// Where a swiped word goes: the text around the cursor when the swipe ended. A word whose place
/// has changed by the time it would go in, because the cursor or the field moved, goes nowhere
/// rather than somewhere the user did not swipe it.
struct KeyboardSwipePlace: Equatable {
    let textBeforeCursor: String?
    let selectedText: String?
    let textAfterCursor: String?
}
