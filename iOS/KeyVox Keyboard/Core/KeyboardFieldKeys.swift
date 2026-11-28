import KeyVoxPredictiveKeyboard
import UIKit

/// The keys the focused field asks for through its keyboard and return key types, as the system
/// keyboard shows them on iPhone, measured on iOS 27 (see `iOS/Docs/ENGINEERING.md`).
struct KeyboardFieldKeys: Hashable {
    /// What the bottom row holds in place of the space bar and return key.
    enum BottomRow: Hashable {
        /// The space bar and return key.
        case standard
        /// A web address field: the dot, the slash, and the common web ending in the space bar's
        /// place, and no space bar.
        case webAddress
        /// A search field that also takes web addresses: a shorter space bar, the dot, and the
        /// return key, on every page.
        case webSearch
        /// An email address field: a shorter space bar, the at sign, and the dot.
        case email
        /// A field for posts: the at sign and the hash sign in the return key's place.
        case socialPost
    }

    /// The number pad a numbers-only field shows in place of the letters.
    enum NumberPad: Hashable {
        /// Digits only.
        case digits
        /// Digits and the decimal separator.
        case decimal
    }

    let bottomRow: BottomRow
    let returnKey: KeyboardReturnKeyStyle
    /// The number pad the field shows instead of the letters, or nil for the letters.
    let numberPad: NumberPad?

    /// The keys of a field that asks for nothing in particular.
    static let standard = KeyboardFieldKeys(keyboardType: .default, returnKeyType: .default)

    /// The text the web ending key types, and which its held popup and the dot's offer: the
    /// ending Apple's keyboard types for the device's region (`KeyboardWebEndings`), the others
    /// around it.
    static var commonWebEnding: String { KeyboardWebEndings.current.ending }

    init(keyboardType: UIKeyboardType, returnKeyType: UIReturnKeyType) {
        switch keyboardType {
        case .URL:
            bottomRow = .webAddress
        case .webSearch:
            bottomRow = .webSearch
        case .emailAddress:
            bottomRow = .email
        case .twitter:
            bottomRow = .socialPost
        default:
            bottomRow = .standard
        }
        switch keyboardType {
        case .numberPad, .asciiCapableNumberPad:
            numberPad = .digits
        case .decimalPad:
            numberPad = .decimal
        default:
            numberPad = nil
        }
        returnKey = KeyboardReturnKeyStyle(returnKeyType: returnKeyType)
    }

    /// The bottom row `page` shows: the field's own on the full letter page, and on the full
    /// symbol pages too for a search field; the standard one in Compact Keys and the emoji search,
    /// which has its own.
    func bottomRow(on page: KeyboardSymbolPage, keysMode: KeyboardKeysMode, isEmojiSearch: Bool) -> BottomRow {
        guard keysMode == .full, isEmojiSearch == false else { return .standard }
        switch page {
        case .letters:
            return bottomRow
        case .primary, .alternate:
            return bottomRow == .webSearch ? .webSearch : .standard
        case .numberPad:
            return .standard
        }
    }
}
