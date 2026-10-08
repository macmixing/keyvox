/// The page and key size the keyboard opens on in a field: full letter keys, unless the field
/// or the user's Open on 123 setting prefers numbers, which opens 123 in the Compact Keys size
/// the user left it in.
struct KeyboardOpeningLayout: Equatable {
    let symbolPage: KeyboardSymbolPage
    let keysMode: KeyboardKeysMode

    static func resolve(
        prefersNumberPage: Bool,
        isCompactKeysEnabled: Bool,
        isCompactKeysActive: Bool
    ) -> KeyboardOpeningLayout {
        guard prefersNumberPage else {
            return KeyboardOpeningLayout(symbolPage: .letters, keysMode: .full)
        }
        return KeyboardOpeningLayout(
            symbolPage: .primary,
            keysMode: .resolve(
                isCompactKeysEnabled: isCompactKeysEnabled,
                isCompactKeysActive: isCompactKeysActive
            )
        )
    }
}
