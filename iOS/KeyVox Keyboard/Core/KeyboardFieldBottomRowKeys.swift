/// The bottom row's keys for a field's `KeyboardFieldKeys.BottomRow`: the keys the field asks for
/// in place of the standard row's space bar and return key, as the system keyboard shows them.
/// `KeyboardLayoutGeometry.BottomRowLayout` sizes them.
enum KeyboardFieldBottomRowKeys {
    /// `row`, a standard bottom row ending in the space bar and return key, with those keys as
    /// `bottomRow` has them.
    static func row(_ row: [KeyboardKeyModel], showing bottomRow: KeyboardFieldKeys.BottomRow) -> [KeyboardKeyModel] {
        guard bottomRow != .standard,
              row.count >= 2,
              row[row.count - 2].kind == .space,
              row[row.count - 1].kind == .returnKey else {
            return row
        }
        return Array(row.dropLast(2)) + trailingKeys(for: bottomRow, replacing: Array(row.suffix(2)))
    }

    /// The keys `bottomRow` shows in place of `standardKeys`, the space bar and return key.
    static func trailingKeys(
        for bottomRow: KeyboardFieldKeys.BottomRow,
        replacing standardKeys: [KeyboardKeyModel]
    ) -> [KeyboardKeyModel] {
        let space = standardKeys[0]
        let returnKey = standardKeys[1]
        switch bottomRow {
        case .standard:
            return standardKeys
        case .webAddress:
            return [
                character("."),
                character("/"),
                character(KeyboardFieldKeys.commonWebEnding),
                returnKey,
            ]
        case .webSearch:
            return [space, character(".", heldOffer: .webEndings), returnKey]
        case .email:
            return [space, character("@"), character(".", heldOffer: .webEndings), returnKey]
        case .socialPost:
            return [space, character("@"), character("#")]
        }
    }

    private static func character(
        _ value: String,
        heldOffer: KeyboardKeyModel.HeldOffer = .ownCharacter
    ) -> KeyboardKeyModel {
        var key = KeyboardSymbolLayout.key(.character(value))
        key.heldOffer = heldOffer
        return key
    }
}
