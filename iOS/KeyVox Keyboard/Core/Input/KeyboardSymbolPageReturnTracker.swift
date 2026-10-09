import KeyVoxPredictiveKeyboard

/// Returns to the letter page as the system keyboard does: right after a character that
/// belongs inside words, such as the apostrophe, and otherwise for the space that follows a
/// character typed on a symbol page, such as a comma or a number.
struct KeyboardSymbolPageReturnTracker {
    private var hasTypedOnSymbolPage = false

    /// The page to show while `kind` is typed, given that `page` is showing.
    mutating func page(for kind: KeyboardKeyKind, on page: KeyboardSymbolPage) -> KeyboardSymbolPage {
        guard page != .letters else {
            hasTypedOnSymbolPage = false
            return page
        }
        switch kind {
        case let .character(value) where value.allSatisfy(TypingTextContext.isWordCharacter):
            hasTypedOnSymbolPage = false
            return .letters
        case .character:
            hasTypedOnSymbolPage = true
            return page
        case .space where hasTypedOnSymbolPage:
            hasTypedOnSymbolPage = false
            return .letters
        default:
            return page
        }
    }
}
