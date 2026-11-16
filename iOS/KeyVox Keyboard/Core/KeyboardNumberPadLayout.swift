import Foundation

/// The number pad a numbers-only field shows, as the system keyboard lays it out on iPhone: three
/// columns of digits, each with the letters a phone keypad gives it, over a bottom row of the
/// decimal separator in a decimal field, zero, and delete. Where the keyboard shows the globe, the
/// globe takes the bottom row's first place, sharing it with the decimal separator.
/// `KeyboardLayoutGeometry.NumberPadBottomRowLayout` sizes the bottom row.
enum KeyboardNumberPadLayout {
    /// A phone keypad's letters, by digit.
    private static let keypadLetters: [String: String] = [
        "2": "ABC",
        "3": "DEF",
        "4": "GHI",
        "5": "JKL",
        "6": "MNO",
        "7": "PQRS",
        "8": "TUV",
        "9": "WXYZ",
    ]

    static func rows(
        for numberPad: KeyboardFieldKeys.NumberPad,
        showsNextKeyboardKey: Bool,
        decimalSeparator: String = Locale.current.decimalSeparator ?? "."
    ) -> [[KeyboardKeyModel]] {
        let digitRows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"]].map { row in
            row.map(padKey)
        }
        var bottomRow: [KeyboardKeyModel] = []
        if showsNextKeyboardKey {
            bottomRow.append(KeyboardSymbolLayout.key(.nextKeyboard))
        }
        if numberPad == .decimal {
            bottomRow.append(padKey(decimalSeparator))
        }
        bottomRow += [padKey("0"), KeyboardSymbolLayout.key(.delete)]
        return digitRows + [bottomRow]
    }

    private static func padKey(_ character: String) -> KeyboardKeyModel {
        var key = KeyboardSymbolLayout.key(.character(character))
        key.isNumberPadKey = true
        // Every digit sits as high as those with letters, so the digits line up across a row.
        key.subtitle = keypadLetters[character] ?? (character.allSatisfy(\.isNumber) ? "" : nil)
        key.heldOffer = .none
        return key
    }
}
