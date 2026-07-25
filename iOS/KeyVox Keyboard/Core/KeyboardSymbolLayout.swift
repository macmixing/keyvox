import Foundation
import UIKit

enum KeyboardSymbolPage {
    case alphabetic
    case primary
    case alternate

    mutating func toggle() {
        switch self {
        case .alphabetic, .alternate:
            self = .primary
        case .primary:
            self = .alternate
        }
    }
}

enum KeyboardKeyKind: Equatable {
    case character(String)
    case delete
    case space
    case returnKey
    case abc
    case shift
    case nextKeyboard
    case alternateSymbols
    case numberSymbols
}

struct KeyboardKeyModel: Equatable {
    let kind: KeyboardKeyKind
    let widthUnits: CGFloat
    let isActive: Bool

    init(kind: KeyboardKeyKind, widthUnits: CGFloat, isActive: Bool = false) {
        self.kind = kind
        self.widthUnits = widthUnits
        self.isActive = isActive
    }

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
        case .shift, .nextKeyboard:
            return ""
        case .alternateSymbols:
            return "#+="
        case .numberSymbols:
            return "123"
        }
    }

    var systemImageName: String? {
        switch kind {
        case .delete:
            return "delete.left"
        case .shift:
            return isActive ? "shift.fill" : "shift"
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
        case .shift:
            return "Shift"
        case .nextKeyboard:
            return "Next Keyboard"
        case .alternateSymbols:
            return "Alternate Symbols"
        case .numberSymbols:
            return "Number Symbols"
        }
    }

    var allowsPopup: Bool {
        switch kind {
        case .character:
            return true
        case .delete, .space, .returnKey, .abc, .shift, .nextKeyboard, .alternateSymbols, .numberSymbols:
            return false
        }
    }

    var isSpecialKey: Bool {
        switch kind {
        case .character:
            return false
        case .delete, .space, .returnKey, .abc, .shift, .nextKeyboard, .alternateSymbols, .numberSymbols:
            return true
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
        letterCase: KeyboardLetterCase = .lowercase
    ) -> [[KeyboardKeyModel]] {
        switch page {
        case .alphabetic:
            return alphabeticRows(letterCase: letterCase)
        case .primary:
            return primaryRows
        case .alternate:
            return alternateRows
        }
    }

    private static func alphabeticRows(
        letterCase: KeyboardLetterCase
    ) -> [[KeyboardKeyModel]] {
        let transform: (String) -> String = letterCase.usesUppercaseLetters
            ? { $0.uppercased() }
            : { $0 }
        return [
            characterRow(Array("qwertyuiop").map { transform(String($0)) }),
            characterRow(Array("asdfghjkl").map { transform(String($0)) }),
            [
                key(
                    .shift,
                    width: 1.45,
                    isActive: letterCase.usesUppercaseLetters
                ),
                key(.character(transform("z"))),
                key(.character(transform("x"))),
                key(.character(transform("c"))),
                key(.character(transform("v"))),
                key(.character(transform("b"))),
                key(.character(transform("n"))),
                key(.character(transform("m"))),
                key(.delete, width: 1.45),
            ],
            [
                key(.numberSymbols, width: 1.55),
                key(.space, width: 4.8),
                key(.returnKey, width: 2.0),
            ],
        ]
    }

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

    private static func key(
        _ kind: KeyboardKeyKind,
        width: CGFloat = 1.0,
        isActive: Bool = false
    ) -> KeyboardKeyModel {
        KeyboardKeyModel(kind: kind, widthUnits: width, isActive: isActive)
    }
}
