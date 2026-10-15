import Foundation
import KeyVoxPredictiveKeyboard
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
    case emoji
    /// Ends the emoji search, in the return key's place while searching.
    case emojiSearchDone
    case restoreFullKeyboard
    case shift
    /// Moves on to the next keyboard, or lists them while held, on an iPhone that shows no globe
    /// under the keyboard.
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
        case .emoji, .emojiSearchDone, .restoreFullKeyboard, .shift, .nextKeyboard:
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
        case .emoji:
            return "face.smiling"
        case .emojiSearchDone:
            return "checkmark"
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
        case .emoji:
            return "Emoji"
        case .emojiSearchDone:
            // Named as the system keyboard names its key.
            return "done"
        case .restoreFullKeyboard:
            return "Full Keyboard"
        case .shift:
            return "Shift"
        case .nextKeyboard:
            // Named as the system keyboard names its key.
            return "Next keyboard"
        }
    }

    var allowsPopup: Bool {
        switch kind {
        case .character:
            return true
        case .delete, .space, .returnKey, .abc, .alternateSymbols, .numberSymbols, .emoji, .emojiSearchDone,
             .restoreFullKeyboard, .shift, .nextKeyboard:
            return false
        }
    }

    var isSpecialKey: Bool {
        switch kind {
        case .character:
            return false
        case .delete, .space, .returnKey, .abc, .alternateSymbols, .numberSymbols, .emoji, .emojiSearchDone,
             .restoreFullKeyboard, .shift, .nextKeyboard:
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
    /// The system keyboard's bottom row on an iPhone with a Home button, which shows no globe under
    /// the keyboard, in top-row keys, measured with Tools/AppleKeyboardBaseline on a 375-point-wide
    /// iPhone SE: 123 and the globe 46 points each, then dictation 37, as wide as a letter, the
    /// space bar 147, and return 92 (`KeyboardSwitchKeyProbeTests`); the emoji search's row is the
    /// same with done for return (`EmojiFrequentlyUsedProbeTests`).
    enum HomeButtonRowMeasured {
        static let pageKeyWidth: CGFloat = 1.25
        static let nextKeyboardWidth: CGFloat = 1.25
        /// The dictation key's width, which the emoji key takes in its place.
        static let emojiWidth: CGFloat = 1
    }

    /// The rows of `page`; while the emoji search shows, the bottom row is the system emoji
    /// keyboard's search row: the page key, space, and done. Without `showsEmojiKey`, the bottom
    /// row has no emoji key; with `showsNextKeyboardKey`, it has the globe after its page key.
    static func rows(
        for page: KeyboardSymbolPage,
        keysMode: KeyboardKeysMode = .full,
        isEmojiSearch: Bool = false,
        showsEmojiKey: Bool = true,
        showsNextKeyboardKey: Bool = false
    ) -> [[KeyboardKeyModel]] {
        var rows = baseRows(for: page, keysMode: keysMode, isEmojiSearch: isEmojiSearch)
        if showsEmojiKey == false, let bottomRow = rows.indices.last {
            rows[bottomRow] = removingEmojiKey(from: rows[bottomRow])
        }
        guard showsNextKeyboardKey, let bottomRow = rows.last else { return rows }
        return rows.dropLast() + [addingNextKeyboardKey(to: bottomRow)]
    }

    private static func baseRows(
        for page: KeyboardSymbolPage,
        keysMode: KeyboardKeysMode,
        isEmojiSearch: Bool
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
        if isEmojiSearch, keysMode == .full {
            rows[rows.count - 1] = [
                key(page == .letters ? .numberSymbols : .abc, width: 2.5),
                key(.space, width: 5.0),
                key(.emojiSearchDone, width: 2.5),
            ]
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
            key(.numberSymbols, width: 1.25),
            key(.emoji, width: 1.25),
            key(.space, width: 5.0),
            key(.returnKey, width: 2.5),
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
            key(.character(SmartQuotes.apostrophe)),
            key(.delete, width: 1.45),
        ],
        [
            key(.abc, width: 1.25),
            key(.emoji, width: 1.25),
            key(.space, width: 5.0),
            key(.returnKey, width: 2.5),
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
            key(.character(SmartQuotes.apostrophe)),
            key(.delete, width: 1.45),
        ],
        [
            key(.abc, width: 1.25),
            key(.emoji, width: 1.25),
            key(.space, width: 5.0),
            key(.returnKey, width: 2.5),
        ],
    ]

    /// `row`, a bottom row, without its emoji key: the page key as wide as return, the space bar
    /// taking what the other keys leave.
    private static func removingEmojiKey(from row: [KeyboardKeyModel]) -> [KeyboardKeyModel] {
        guard row.contains(where: { $0.kind == .emoji }), let pageKey = row.first else { return row }
        let returnWidth = row.first { $0.kind == .returnKey }?.widthUnits ?? pageKey.widthUnits
        let keys = [key(pageKey.kind, width: returnWidth)] + row.dropFirst().filter { $0.kind != .emoji }
        let rowWidth = row.reduce(0) { $0 + $1.widthUnits }
        let otherKeysWidth = keys.filter { $0.kind != .space }.reduce(0) { $0 + $1.widthUnits }
        return keys.map { $0.kind == .space ? key(.space, width: rowWidth - otherKeysWidth) : $0 }
    }

    /// `row`, a bottom row, as the system keyboard shows it on an iPhone with a Home button: the
    /// globe after the page key and the emoji key in the dictation key's place, the space bar taking
    /// what the other keys leave.
    private static func addingNextKeyboardKey(to row: [KeyboardKeyModel]) -> [KeyboardKeyModel] {
        guard let pageKey = row.first else { return row }
        let keys = [
            key(pageKey.kind, width: HomeButtonRowMeasured.pageKeyWidth),
            key(.nextKeyboard, width: HomeButtonRowMeasured.nextKeyboardWidth),
        ] + row.dropFirst().map { $0.kind == .emoji ? key(.emoji, width: HomeButtonRowMeasured.emojiWidth) : $0 }
        let rowWidth = row.reduce(0) { $0 + $1.widthUnits }
        let otherKeysWidth = keys.filter { $0.kind != .space }.reduce(0) { $0 + $1.widthUnits }
        return keys.map { $0.kind == .space ? key(.space, width: rowWidth - otherKeysWidth) : $0 }
    }

    private static func characterRow(_ characters: [String]) -> [KeyboardKeyModel] {
        characters.map { key(.character($0)) }
    }

    private static func key(_ kind: KeyboardKeyKind, width: CGFloat = 1.0) -> KeyboardKeyModel {
        KeyboardKeyModel(kind: kind, widthUnits: width)
    }
}
