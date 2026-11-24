import KeyVoxPredictiveKeyboard
import UIKit

/// The letter page's letter rows, drawn from the typing language's letter layout
/// (`TypingLanguage.letterLayout`), with every width in letter keys: the layout's keys at Apple's
/// widths, shift and delete taking in the padding beside them so they reach the row's letters, and
/// any other padding left empty, at the row's edges or between its keys.
struct KeyboardLetterRows {
    struct Row {
        /// The row's keys, left to right, each `widthUnits` letter keys wide.
        let keys: [KeyboardKeyModel]
        /// Empty space before the first key.
        let leadingInset: CGFloat
        /// Empty space after the last key.
        let trailingInset: CGFloat
        /// Empty space after each key, beyond the usual gap between keys.
        let extraSpacing: [CGFloat]

        /// Whether the row is `layoutWidth` one-letter-wide keys with nothing around or between
        /// them, so equal keys across the row lay it out.
        func fillsEvenly(layoutWidth: CGFloat) -> Bool {
            CGFloat(keys.count) == layoutWidth
                && keys.allSatisfy { $0.widthUnits == 1 }
                && leadingInset == 0
                && trailingInset == 0
                && extraSpacing.allSatisfy { $0 == 0 }
        }
    }

    /// The rows of the language the keyboard types in.
    static let current = KeyboardLetterRows(layout: KeyboardTypingLanguage.current.letterLayout)

    let rows: [Row]
    /// How wide every row is.
    let width: CGFloat

    init(layout: LetterKeyLayout) {
        rows = layout.rows.map(Self.row)
        width = CGFloat(layout.width)
    }

    private static func row(_ row: LetterKeyRow) -> Row {
        var keys: [KeyboardKeyModel] = []
        var extraSpacing: [CGFloat] = []
        var leadingInset: CGFloat = 0
        var trailingInset: CGFloat = 0
        var paddingBeforeSideKey: CGFloat = 0
        for (index, item) in row.items.enumerated() {
            let width = CGFloat(item.width)
            let kind: KeyboardKeyKind
            switch item {
            case let .character(text):
                kind = .character(text)
            case .shift:
                kind = .shift
            case .delete:
                kind = .delete
            case .padding:
                let next = row.items.dropFirst(index + 1).first
                if let last = keys.last, last.isSideKey {
                    keys[keys.count - 1] = KeyboardSymbolLayout.key(last.kind, width: last.widthUnits + width)
                } else if let next, isSideKey(next) {
                    paddingBeforeSideKey += width
                } else if keys.isEmpty {
                    leadingInset += width
                } else if next == nil {
                    trailingInset += width
                } else {
                    extraSpacing[extraSpacing.count - 1] += width
                }
                continue
            }
            keys.append(KeyboardSymbolLayout.key(kind, width: paddingBeforeSideKey + width))
            extraSpacing.append(0)
            paddingBeforeSideKey = 0
        }
        return Row(
            keys: keys,
            leadingInset: leadingInset,
            trailingInset: trailingInset,
            extraSpacing: extraSpacing
        )
    }

    private static func isSideKey(_ item: LetterKeyRow.Item) -> Bool {
        switch item {
        case .shift, .delete:
            return true
        case .character, .padding:
            return false
        }
    }
}

private extension KeyboardKeyModel {
    /// Whether the key is shift or delete, which take in the padding beside them.
    var isSideKey: Bool {
        kind == .shift || kind == .delete
    }
}
