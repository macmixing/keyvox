import UIKit

enum KeyboardLayoutGeometry {
    class RowLayout {
        weak var keyGridView: KeyboardKeyGridView?
        weak var rowStack: UIStackView?
        var widthConstraints: [NSLayoutConstraint] = []

        init(keyGridView: KeyboardKeyGridView, rowStack: UIStackView) {
            self.keyGridView = keyGridView
            self.rowStack = rowStack
        }

        func applyLayout(expectedKeyCount: Int, targetWidths: [CGFloat]) {
            guard let rowStack else { return }

            let keyViews = rowStack.arrangedSubviews.compactMap { $0 as? KeyboardKeyView }
            guard keyViews.count == expectedKeyCount else { return }

            rowStack.distribution = .fill

            if widthConstraints.count != targetWidths.count {
                NSLayoutConstraint.deactivate(widthConstraints)
                // The widths follow the grid's width only once the grid lays out, so after the
                // grid resizes they can briefly ask for more or less than the row holds. Just
                // below required, they give way then instead of forcing Auto Layout to break a
                // key's constraints, which can leave its engine unable to remove the key later.
                widthConstraints = zip(keyViews, targetWidths).map { keyView, width in
                    let constraint = keyView.widthAnchor.constraint(equalToConstant: width)
                    constraint.priority = .required - 1
                    return constraint
                }
                NSLayoutConstraint.activate(widthConstraints)
                return
            }

            for (constraint, width) in zip(widthConstraints, targetWidths) {
                constraint.constant = width
            }
        }
    }

    final class ThirdRowLayout: RowLayout {
        func update(isLandscape _: Bool) {
            guard let keyGridView else { return }

            let spacing = KeyboardStyle.keySpacing
            let rowWidth = keyGridView.bounds.width
            let topRowKeyWidth = (rowWidth - (spacing * 9)) / 10
            let specialKeyWidth = (topRowKeyWidth * 1.5) + (spacing * 0.5)
            let middleKeyWidth = (rowWidth - (specialKeyWidth * 2) - (spacing * 6)) / 5

            guard specialKeyWidth > 0, middleKeyWidth > 0 else { return }

            let targetWidths = [
                specialKeyWidth,
                middleKeyWidth,
                middleKeyWidth,
                middleKeyWidth,
                middleKeyWidth,
                middleKeyWidth,
                specialKeyWidth,
            ]

            applyLayout(expectedKeyCount: 7, targetWidths: targetWidths)
        }
    }

    /// The letter page's middle row: nine top-row-width keys inset half a key on each side.
    final class LetterSecondRowLayout: RowLayout {
        func update(isLandscape _: Bool) {
            guard let keyGridView, let rowStack else { return }

            let spacing = KeyboardStyle.keySpacing
            let rowWidth = keyGridView.bounds.width
            let topRowKeyWidth = (rowWidth - (spacing * 9)) / 10
            let horizontalInset = (topRowKeyWidth + spacing) / 2
            guard topRowKeyWidth > 0 else { return }

            rowStack.isLayoutMarginsRelativeArrangement = true
            rowStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
                top: 0,
                leading: horizontalInset,
                bottom: 0,
                trailing: horizontalInset
            )
            applyLayout(expectedKeyCount: 9, targetWidths: Array(repeating: topRowKeyWidth, count: 9))
        }
    }

    /// The letter page's shift row: shift and delete flank seven top-row-width letters.
    final class LetterThirdRowLayout: RowLayout {
        func update(isLandscape _: Bool) {
            guard let keyGridView else { return }

            let spacing = KeyboardStyle.keySpacing
            let rowWidth = keyGridView.bounds.width
            let topRowKeyWidth = (rowWidth - (spacing * 9)) / 10
            let specialKeyWidth = (topRowKeyWidth * 1.5) + (spacing * 0.5)
            guard topRowKeyWidth > 0 else { return }

            let targetWidths = [specialKeyWidth]
                + Array(repeating: topRowKeyWidth, count: 7)
                + [specialKeyWidth]
            applyLayout(expectedKeyCount: 9, targetWidths: targetWidths)
        }
    }

    final class BottomRowLayout: RowLayout {
        private let bottomRow: KeyboardFieldKeys.BottomRow

        init(keyGridView: KeyboardKeyGridView, rowStack: UIStackView, bottomRow: KeyboardFieldKeys.BottomRow) {
            self.bottomRow = bottomRow
            super.init(keyGridView: keyGridView, rowStack: rowStack)
        }

        func update(isLandscape: Bool) {
            guard let keyGridView, let rowStack,
                  let widths = Self.widths(
                      rowWidth: keyGridView.bounds.width,
                      keyCount: rowStack.arrangedSubviews.count,
                      bottomRow: bottomRow,
                      isLandscape: isLandscape
                  ) else { return }
            applyLayout(expectedKeyCount: widths.count, targetWidths: widths)
        }

        /// The widths of a bottom row of `keyCount` keys ending in `bottomRow`'s keys, or nil when
        /// the row is too narrow or holds no such keys.
        static func widths(
            rowWidth: CGFloat,
            keyCount: Int,
            bottomRow: KeyboardFieldKeys.BottomRow,
            isLandscape: Bool
        ) -> [CGFloat]? {
            let spacing = KeyboardStyle.keySpacing
            let topRowKeyWidth = (rowWidth - (spacing * 9)) / 10
            // In landscape the side keys span two top-row keys, leaving the space bar the six
            // between, as on Apple's landscape keyboard.
            let sideKeyWidth = isLandscape
                ? (topRowKeyWidth * 2) + spacing
                : (topRowKeyWidth * 2.5) + (spacing * 1.5)
            // The page key and the emoji key share a side key's width, as on Apple's keyboard
            // (measured with Tools/AppleKeyboardBaseline, `EmojiKeyboardProbeTests`); in the emoji
            // search's row, without the emoji key, the page key takes the side key's width
            // (`EmojiFrequentlyUsedProbeTests`).
            let pairedKeyWidth = (sideKeyWidth - spacing) / 2
            var spaceSlotWidth = rowWidth - (sideKeyWidth * 2) - (spacing * 2)

            // On an iPhone with a Home button the globe follows the page key, as wide as it, and the
            // emoji key takes the dictation key's place, a top-row key wide, as on Apple's keyboard
            // there (`KeyboardSymbolLayout.HomeButtonRowMeasured`); the emoji search's row, with the
            // globe and without the emoji key, has the usual row's widths.
            let leadingWidths: [CGFloat]
            switch keyCount - trailingKeyCount(of: bottomRow) {
            case 1:
                leadingWidths = [sideKeyWidth]
            case 2:
                leadingWidths = [pairedKeyWidth, pairedKeyWidth]
            case 3:
                leadingWidths = [pairedKeyWidth, pairedKeyWidth, topRowKeyWidth]
                spaceSlotWidth -= topRowKeyWidth + spacing
            default:
                return nil
            }

            // A field's keys split the space bar's and the return key's places as the system
            // keyboard splits them, measured on iOS 27 (`iOS/Docs/ENGINEERING.md`): web address
            // keys share the space bar's place in thirds; the email keys and the post keys are as
            // wide as the page key; a search field's dot and return key share the return key's
            // place one third to two, the space bar giving up a key gap.
            let returnSlotWidth = sideKeyWidth
            let trailingWidths: [CGFloat]
            switch bottomRow {
            case .standard:
                trailingWidths = [spaceSlotWidth, returnSlotWidth]
            case .webAddress:
                let third = (spaceSlotWidth - (spacing * 2)) / 3
                trailingWidths = [third, third, third, returnSlotWidth]
            case .webSearch:
                trailingWidths = [spaceSlotWidth - spacing, returnSlotWidth / 3, returnSlotWidth * 2 / 3]
            case .email:
                trailingWidths = [
                    spaceSlotWidth - (pairedKeyWidth * 2) - (spacing * 2),
                    pairedKeyWidth,
                    pairedKeyWidth,
                    returnSlotWidth,
                ]
            case .socialPost:
                trailingWidths = [spaceSlotWidth, pairedKeyWidth, pairedKeyWidth]
            }
            let widths = leadingWidths + trailingWidths
            return widths.allSatisfy { $0 > 0 } ? widths : nil
        }

        /// How many keys `bottomRow` puts in the space bar's and the return key's places.
        private static func trailingKeyCount(of bottomRow: KeyboardFieldKeys.BottomRow) -> Int {
            switch bottomRow {
            case .standard:
                return 2
            case .webSearch, .socialPost:
                return 3
            case .webAddress, .email:
                return 4
            }
        }
    }

    /// The number pad's bottom row in its three columns: zero and delete under the last two, the
    /// first left empty, or holding the decimal separator, or the globe, or both side by side.
    final class NumberPadBottomRowLayout: RowLayout {
        func update(isLandscape _: Bool) {
            guard let keyGridView, let rowStack else { return }

            let spacing = KeyboardStyle.keySpacing
            let columnWidth = (keyGridView.bounds.width - (spacing * 2)) / 3
            guard columnWidth > 0 else { return }

            let keyCount = rowStack.arrangedSubviews.count
            let leadingInset = keyCount == 2 ? columnWidth + spacing : 0
            rowStack.isLayoutMarginsRelativeArrangement = true
            rowStack.directionalLayoutMargins = NSDirectionalEdgeInsets(
                top: 0,
                leading: leadingInset,
                bottom: 0,
                trailing: 0
            )
            let sharedWidth = (columnWidth - spacing) / 2
            let targetWidths = keyCount == 4
                ? [sharedWidth, sharedWidth, columnWidth, columnWidth]
                : Array(repeating: columnWidth, count: keyCount)
            applyLayout(expectedKeyCount: keyCount, targetWidths: targetWidths)
        }
    }
}
