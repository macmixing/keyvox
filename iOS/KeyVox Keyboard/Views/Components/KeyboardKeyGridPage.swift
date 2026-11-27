import UIKit

/// One page of the key grid: the letter, number, or symbol keys in one keys mode, or the number
/// pad, with the emoji search's bottom row or the focused field's, with or without the globe, and
/// for the letter page the letter layout it draws, built once and kept, so switching pages or back
/// to a layout shows a page that already exists instead of building it again.
final class KeyboardKeyGridPage {
    struct Layout: Hashable {
        let symbolPage: KeyboardSymbolPage
        let keysMode: KeyboardKeysMode
        let isEmojiSearch: Bool
        let showsEmojiKey: Bool
        let showsNextKeyboardKey: Bool
        let fieldKeys: KeyboardFieldKeys
        /// The letter layout the letter page draws (`KeyboardLetterRows.current`).
        let letterLayout: String
    }

    /// The page's rows, stacked top to bottom.
    let view = UIStackView()
    private(set) var keyViews: [KeyboardKeyView] = []
    private var baseModels: [ObjectIdentifier: KeyboardKeyModel] = [:]
    private var letterCase: KeyboardLetterCase
    private var accentKeyLabel: KeyboardAccentKeyLabel?
    private let isNumberPad: Bool
    private var letterRowLayoutGeometries: [KeyboardLayoutGeometry.LetterRowLayout] = []
    private var thirdRowLayoutGeometry: KeyboardLayoutGeometry.ThirdRowLayout?
    private var bottomRowLayoutGeometry: KeyboardLayoutGeometry.BottomRowLayout?
    private var numberPadBottomRowLayoutGeometry: KeyboardLayoutGeometry.NumberPadBottomRowLayout?

    init(layout: Layout, letterCase: KeyboardLetterCase, keyGridView: KeyboardKeyGridView) {
        self.letterCase = letterCase
        isNumberPad = layout.symbolPage == .numberPad
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .fillEqually
        view.spacing = KeyboardStyle.keyboardRowSpacing
        view.clipsToBounds = false

        let letterRows = KeyboardLetterRows.current
        let rows = KeyboardSymbolLayout.rows(
            for: layout.symbolPage,
            keysMode: layout.keysMode,
            isEmojiSearch: layout.isEmojiSearch,
            showsEmojiKey: layout.showsEmojiKey,
            showsNextKeyboardKey: layout.showsNextKeyboardKey,
            fieldKeys: layout.fieldKeys
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

            let isBottomRow = rowIndex == rows.count - 1
            if layout.symbolPage == .numberPad {
                if isBottomRow {
                    numberPadBottomRowLayoutGeometry = KeyboardLayoutGeometry.NumberPadBottomRowLayout(
                        keyGridView: keyGridView,
                        rowStack: rowStack
                    )
                }
            } else if layout.symbolPage == .letters, layout.keysMode == .full,
                      letterRows.rows.indices.contains(rowIndex) {
                let letterRow = letterRows.rows[rowIndex]
                if letterRow.fillsEvenly(layoutWidth: letterRows.width) == false {
                    letterRowLayoutGeometries.append(KeyboardLayoutGeometry.LetterRowLayout(
                        keyGridView: keyGridView,
                        rowStack: rowStack,
                        row: letterRow,
                        layoutWidth: letterRows.width
                    ))
                }
            } else if rowModels.contains(where: { $0.kind == .delete }) {
                thirdRowLayoutGeometry = KeyboardLayoutGeometry.ThirdRowLayout(
                    keyGridView: keyGridView,
                    rowStack: rowStack
                )
            } else if isBottomRow {
                bottomRowLayoutGeometry = KeyboardLayoutGeometry.BottomRowLayout(
                    keyGridView: keyGridView,
                    rowStack: rowStack,
                    bottomRow: layout.fieldKeys.bottomRow(
                        on: layout.symbolPage,
                        keysMode: layout.keysMode,
                        isEmojiSearch: layout.isEmojiSearch
                    )
                )
            }
        }
    }

    /// Shows letter keys in `letterCase`, relabeling only the keys whose label changes.
    func apply(letterCase: KeyboardLetterCase, isTrackpadModeActive: Bool) {
        guard letterCase != self.letterCase else { return }
        self.letterCase = letterCase
        relabelKeys(isTrackpadModeActive: isTrackpadModeActive)
    }

    /// Shows the accent key as `accentKeyLabel` says, or as the layout draws it when nil.
    func apply(accentKeyLabel: KeyboardAccentKeyLabel?, isTrackpadModeActive: Bool) {
        guard accentKeyLabel != self.accentKeyLabel else { return }
        self.accentKeyLabel = accentKeyLabel
        relabelKeys(isTrackpadModeActive: isTrackpadModeActive)
    }

    /// Relabels the keys whose label the letter case or the accent key's label changes.
    private func relabelKeys(isTrackpadModeActive: Bool) {
        for keyView in keyViews {
            guard let baseModel = baseModels[ObjectIdentifier(keyView)] else { continue }
            let casedModel = baseModel.applying(letterCase).showing(accentKeyLabel)
            guard casedModel != keyView.model else { continue }
            keyView.apply(
                model: casedModel,
                state: keyView.visualState,
                isTrackpadModeActive: isTrackpadModeActive,
                animated: false
            )
        }
    }

    /// Sizes the rows whose keys are not all the same width to the grid's current width, and
    /// centers the number pad's rows in `numberPadWidth`.
    func updateRowLayouts(isLandscape: Bool, numberPadWidth: CGFloat, gridWidth: CGFloat) {
        if isNumberPad {
            let sideInset = (gridWidth - numberPadWidth) / 2
            // The pad reaches the keyboard's bottom edge, over the home indicator in landscape;
            // margins that took in the safe area there would shorten its bottom row.
            view.insetsLayoutMarginsFromSafeArea = false
            view.isLayoutMarginsRelativeArrangement = true
            view.directionalLayoutMargins = NSDirectionalEdgeInsets(
                top: 0,
                leading: sideInset,
                bottom: 0,
                trailing: sideInset
            )
        }
        letterRowLayoutGeometries.forEach { $0.update() }
        thirdRowLayoutGeometry?.update(isLandscape: isLandscape)
        bottomRowLayoutGeometry?.update(isLandscape: isLandscape)
        numberPadBottomRowLayoutGeometry?.update(padWidth: numberPadWidth)
    }
}
