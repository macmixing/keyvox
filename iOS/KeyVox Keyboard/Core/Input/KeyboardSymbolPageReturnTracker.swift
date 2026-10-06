/// Returns to the letter page for the space that follows a character typed on a symbol
/// page, as the system keyboard does after a comma, a number, or any other symbol.
struct KeyboardSymbolPageReturnTracker {
    private var hasTypedOnSymbolPage = false

    /// The page to show while `kind` is typed, given that `page` is showing.
    mutating func page(for kind: KeyboardKeyKind, on page: KeyboardSymbolPage) -> KeyboardSymbolPage {
        guard page != .letters else {
            hasTypedOnSymbolPage = false
            return page
        }
        switch kind {
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
