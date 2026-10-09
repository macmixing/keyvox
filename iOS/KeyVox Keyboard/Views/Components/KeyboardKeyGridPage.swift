import UIKit

/// One page of the key grid: the letter, number, or symbol keys in one keys mode, built once
/// and kept, so switching pages shows a page that already exists instead of building it again.
final class KeyboardKeyGridPage {
    struct Layout: Hashable {
        let symbolPage: KeyboardSymbolPage
        let keysMode: KeyboardKeysMode
        let showsNextKeyboardKey: Bool
    }

    /// The page's rows, stacked top to bottom.
    let view = UIStackView()
    private(set) var keyViews: [KeyboardKeyView] = []
    private var baseModels: [ObjectIdentifier: KeyboardKeyModel] = [:]
    private var letterCase: KeyboardLetterCase
    private var letterSecondRowLayoutGeometry: KeyboardLayoutGeometry.LetterSecondRowLayout?
    private var letterThirdRowLayoutGeometry: KeyboardLayoutGeometry.LetterThirdRowLayout?
    private var thirdRowLayoutGeometry: KeyboardLayoutGeometry.ThirdRowLayout?
    private var bottomRowLayoutGeometry: KeyboardLayoutGeometry.BottomRowLayout?

    init(layout: Layout, letterCase: KeyboardLetterCase, keyGridView: KeyboardKeyGridView) {
        self.letterCase = letterCase
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .fillEqually
        view.spacing = KeyboardStyle.keyboardRowSpacing
        view.clipsToBounds = false

        let rows = KeyboardSymbolLayout.rows(
            for: layout.symbolPage,
            keysMode: layout.keysMode,
            showsNextKeyboardKey: layout.showsNextKeyboardKey
        )
        for (rowIndex, rowModels) in rows.enumerated() {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.alignment = .fill
            rowStack.distribution = rowModels.allSatisfy { $0.widthUnits == 1 }
                ? .fillEqually
                : .fillProportionally
            rowStack.spacing = KeyboardStyle.keySpacing
            rowStack.translatesAutoresizingMaskIntoConstraints = false

            for model in rowModels {
                let keyView = KeyboardKeyView(model: model.applying(letterCase))
                keyViews.append(keyView)
                baseModels[ObjectIdentifier(keyView)] = model
                rowStack.addArrangedSubview(keyView)
            }

            view.addArrangedSubview(rowStack)

            if layout.symbolPage == .letters, layout.keysMode == .full, rowIndex == 1 {
                letterSecondRowLayoutGeometry = KeyboardLayoutGeometry.LetterSecondRowLayout(
                    keyGridView: keyGridView,
                    rowStack: rowStack
                )
            } else if rowModels.contains(where: { $0.kind == .delete }) {
                if layout.symbolPage == .letters {
                    letterThirdRowLayoutGeometry = KeyboardLayoutGeometry.LetterThirdRowLayout(
                        keyGridView: keyGridView,
                        rowStack: rowStack
                    )
                } else {
                    thirdRowLayoutGeometry = KeyboardLayoutGeometry.ThirdRowLayout(
                        keyGridView: keyGridView,
                        rowStack: rowStack
                    )
                }
            } else if rowModels.contains(where: { $0.kind == .space }) {
                bottomRowLayoutGeometry = KeyboardLayoutGeometry.BottomRowLayout(
                    keyGridView: keyGridView,
                    rowStack: rowStack
                )
            }
        }
    }

    /// Shows letter keys in `letterCase`, relabeling only the keys whose label changes.
    func apply(letterCase: KeyboardLetterCase, isTrackpadModeActive: Bool) {
        guard letterCase != self.letterCase else { return }
        self.letterCase = letterCase
        for keyView in keyViews {
            guard let baseModel = baseModels[ObjectIdentifier(keyView)] else { continue }
            let casedModel = baseModel.applying(letterCase)
            guard casedModel != keyView.model else { continue }
            keyView.apply(
                model: casedModel,
                state: keyView.visualState,
                isTrackpadModeActive: isTrackpadModeActive,
                animated: false
            )
        }
    }

    /// Sizes the rows whose keys are not all the same width to the grid's current width.
    func updateRowLayouts(isLandscape: Bool) {
        letterSecondRowLayoutGeometry?.update(isLandscape: isLandscape)
        letterThirdRowLayoutGeometry?.update(isLandscape: isLandscape)
        thirdRowLayoutGeometry?.update(isLandscape: isLandscape)
        bottomRowLayoutGeometry?.update(isLandscape: isLandscape)
    }
}
