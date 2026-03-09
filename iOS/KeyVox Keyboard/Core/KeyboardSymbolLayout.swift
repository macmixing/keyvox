import Foundation
import UIKit

enum KeyboardSymbolPage {
    case primary
    case alternate

    mutating func toggle() {
        self = self == .primary ? .alternate : .primary
    }
}

enum KeyboardKeyKind: Equatable {
    case character(String)
    case delete
    case space
    case returnKey
    case abc
    case alternateSymbols
    case numberSymbols
}

struct KeyboardKeyModel: Equatable {
    let kind: KeyboardKeyKind
    let widthUnits: CGFloat

    var title: String {
        switch kind {
        case let .character(value):
            return value
        case .delete:
            return ""
        case .space:
            return "space"
        case .returnKey:
            return "return"
        case .abc:
            return "ABC"
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
        }
    }

    var allowsPopup: Bool {
        switch kind {
        case .character:
            return true
        case .delete, .space, .returnKey, .abc, .alternateSymbols, .numberSymbols:
            return false
        }
    }

    var isSpecialKey: Bool {
        switch kind {
        case .character:
            return false
        case .delete, .space, .returnKey, .abc, .alternateSymbols, .numberSymbols:
            return true
        }
    }

    var popupText: String? {
        guard case let .character(value) = kind else { return nil }
        return value
    }
}

enum KeyboardSymbolLayout {
    static func rows(for page: KeyboardSymbolPage) -> [[KeyboardKeyModel]] {
        switch page {
        case .primary:
            return primaryRows
        case .alternate:
            return alternateRows
        }
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
            key(.character("'")),
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
        characterRow(["_", "\\", "|", "~", "<", ">", "€", "£", "¥", "·"]),
        [
            key(.numberSymbols, width: 1.45),
            key(.character(".")),
            key(.character(",")),
            key(.character("?")),
            key(.character("!")),
            key(.character("'")),
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
