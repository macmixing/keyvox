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
                widthConstraints = zip(keyViews, targetWidths).map { keyView, width in
                    keyView.widthAnchor.constraint(equalToConstant: width)
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
        func update(isLandscape _: Bool) {
            guard let keyGridView, let rowStack else { return }

            let spacing = KeyboardStyle.keySpacing
            let rowWidth = keyGridView.bounds.width
            let topRowKeyWidth = (rowWidth - (spacing * 9)) / 10
            let sideKeyWidth = (topRowKeyWidth * 2.5) + (spacing * 1.5)
            let keyCount = rowStack.arrangedSubviews.count

            if keyCount == 4 {
                let leadingKeyWidth = sideKeyWidth - topRowKeyWidth - spacing
                let spaceKeyWidth = rowWidth - leadingKeyWidth - topRowKeyWidth - sideKeyWidth - (spacing * 3)
                guard leadingKeyWidth > 0, spaceKeyWidth > 0 else { return }
                applyLayout(
                    expectedKeyCount: 4,
                    targetWidths: [leadingKeyWidth, topRowKeyWidth, spaceKeyWidth, sideKeyWidth]
                )
                return
            }

            let spaceKeyWidth = rowWidth - (sideKeyWidth * 2) - (spacing * 2)

            guard sideKeyWidth > 0, spaceKeyWidth > 0 else { return }

            let targetWidths = [
                sideKeyWidth,
                spaceKeyWidth,
                sideKeyWidth,
            ]

            applyLayout(expectedKeyCount: 3, targetWidths: targetWidths)
        }
    }
}
