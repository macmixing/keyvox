import Foundation
import UIKit

enum KeyboardSymbolPage {
    case letters
    case primary
    case alternate
}

enum KeyboardKeyKind: Equatable {
    case character(String)
    case delete
    case space
    case returnKey
    case abc
    case alternateSymbols
    case numberSymbols
    case restoreFullKeyboard
    case shift
    case nextKeyboard
}

struct KeyboardKeyModel: Equatable {
    let kind: KeyboardKeyKind
    let widthUnits: CGFloat
    /// Shown by the shift key; letter keys carry their case in their character.
    var letterCase: KeyboardLetterCase = .lowercase

    var title: String {
        switch kind {
        case let .character(value):
            return value
        case .delete:
            return ""
        case .space:
            return ""
        case .returnKey:
            return "⏎"
        case .abc:
            return "ABC"
        case .alternateSymbols:
            return "#+="
        case .numberSymbols:
            return "123"
        case .restoreFullKeyboard, .shift, .nextKeyboard:
            return ""
        }
    }

    var systemImageName: String? {
        switch kind {
        case .delete:
            return "delete.left"
        case .restoreFullKeyboard:
            return "keyboard"
        case .shift:
            switch letterCase {
            case .lowercase:
                return "shift"
            case .shifted:
                return "shift.fill"
            case .capsLocked:
                return "capslock.fill"
            }
        case .nextKeyboard:
            return "globe"
        default:
            return nil
        }
    }

    var accessibilityLabel: String {
        switch kind {
        case let .character(value):
            return value
        case .delete:
            return "Delete"
        case .space:
            return "Space"
        case .returnKey:
            return "Return"
        case .abc:
            return "ABC"
        case .alternateSymbols:
            return "Alternate Symbols"
        case .numberSymbols:
            return "Number Symbols"
        case .restoreFullKeyboard:
            return "Full Keyboard"
        case .shift:
            return "Shift"
        case .nextKeyboard:
            return "Next Keyboard"
        }
    }

    var allowsPopup: Bool {
        switch kind {
        case .character:
            return true
        case .delete, .space, .returnKey, .abc, .alternateSymbols, .numberSymbols, .restoreFullKeyboard,
             .shift, .nextKeyboard:
            return false
        }
    }

    var isSpecialKey: Bool {
        switch kind {
        case .character:
            return false
        case .delete, .space, .returnKey, .abc, .alternateSymbols, .numberSymbols, .restoreFullKeyboard,
             .shift, .nextKeyboard:
            return true
        }
    }

    /// The same key showing `letterCase`: letters switch case and the shift key its symbol.
    func applying(_ letterCase: KeyboardLetterCase) -> KeyboardKeyModel {
        switch kind {
        case let .character(value) where value.count == 1 && value.lowercased() != value.uppercased():
            let cased = letterCase.usesUppercaseLetters ? value.uppercased() : value.lowercased()
            return KeyboardKeyModel(kind: .character(cased), widthUnits: widthUnits)
        case .shift:
            return KeyboardKeyModel(kind: .shift, widthUnits: widthUnits, letterCase: letterCase)
        default:
            return self
        }
    }

    var popupText: String? {
        guard case let .character(value) = kind else { return nil }
        return value
    }

    var titleFont: UIFont {
        switch kind {
        case .character("•"):
            return UIFont.systemFont(ofSize: KeyboardStyle.keyFont.pointSize, weight: .black)
        case .returnKey:
            return KeyboardStyle.specialKeyFont.withSize(KeyboardStyle.specialKeyFont.pointSize * 1.5)
        default:
            return isSpecialKey ? KeyboardStyle.specialKeyFont : KeyboardStyle.keyFont
        }
    }

    var titleBaselineOffset: CGFloat {
        switch kind {
        case .character("•"), .character("("), .character(")"), .character(";"), .character(":"), .character("-"), .character("/"), .character("\\"), .character("|"), .character("~"), .character("<"), .character(">"), .character("["), .character("]"), .character("{"), .character("}"), .character("+"), .character("="):
            return 6
        default:
            return 0
        }
    }

    func attributedTitle(for text: String? = nil) -> NSAttributedString {
        NSAttributedString(
            string: text ?? title,
            attributes: [.baselineOffset: titleBaselineOffset]
        )
    }
}

enum KeyboardSymbolLayout {
    static func rows(
        for page: KeyboardSymbolPage,
        keysMode: KeyboardKeysMode = .full,
        showsNextKeyboardKey: Bool = false
    ) -> [[KeyboardKeyModel]] {
        var rows: [[KeyboardKeyModel]]
        switch page {
        case .letters:
            rows = letterRows
        case .primary:
            rows = primaryRows
        case .alternate:
            rows = alternateRows
        }
        if showsNextKeyboardKey, let bottomRow = rows.indices.last {
            rows[bottomRow].insert(key(.nextKeyboard, width: 1.0), at: 1)
        }

        switch keysMode {
        case .full:
            return rows
        case .compact:
            var compactRows = Array(primaryRows.suffix(keysMode.visibleRowCount))
            guard compactRows.isEmpty == false, compactRows[0].isEmpty == false else {
                return compactRows
            }
            let compactToggleWidth = compactRows[0][0].widthUnits
            compactRows[0][0] = key(.restoreFullKeyboard, width: compactToggleWidth)
            return compactRows
        }
    }

    private static let letterRows: [[KeyboardKeyModel]] = [
        characterRow(["q", "w", "e", "r", "t", "y", "u", "i", "o", "p"]),
        characterRow(["a", "s", "d", "f", "g", "h", "j", "k", "l"]),
        [key(.shift, width: 1.45)]
            + characterRow(["z", "x", "c", "v", "b", "n", "m"])
            + [key(.delete, width: 1.45)],
        [
            key(.numberSymbols, width: 1.55),
            key(.space, width: 4.8),
            key(.returnKey, width: 2.0),
        ],
    ]

    private static let primaryRows: [[KeyboardKeyModel]] = [
        characterRow(["1", "2", "3", "4", "5", "6", "7", "8", "9", "0"]),
        characterRow(["-", "/", ":", ";", "(", ")", "$", "&", "@", "\""]),
        [
            key(.alternateSymbols, width: 1.45),
            key(.character(".")),
            key(.character(",")),
            key(.character("?")),
            key(.character("!")),
            key(.character("‘")),
            key(.delete, width: 1.45),
        ],
        [
            key(.abc, width: 1.55),
            key(.space, width: 4.8),
            key(.returnKey, width: 2.0),
        ],
    ]

    private static let alternateRows: [[KeyboardKeyModel]] = [
        characterRow(["[", "]", "{", "}", "#", "%", "^", "*", "+", "="]),
        characterRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "•"]),
        [
            key(.numberSymbols, width: 1.45),
            key(.character(".")),
            key(.character(",")),
            key(.character("?")),
            key(.character("!")),
            key(.character("’")),
            key(.delete, width: 1.45),
        ],
        [
            key(.abc, width: 1.55),
            key(.space, width: 4.8),
            key(.returnKey, width: 2.0),
        ],
    ]

    private static func characterRow(_ characters: [String]) -> [KeyboardKeyModel] {
        characters.map { key(.character($0)) }
    }

    private static func key(_ kind: KeyboardKeyKind, width: CGFloat = 1.0) -> KeyboardKeyModel {
        KeyboardKeyModel(kind: kind, widthUnits: width)
    }
}
