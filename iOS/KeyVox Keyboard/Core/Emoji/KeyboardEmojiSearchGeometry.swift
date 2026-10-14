import CoreGraphics

/// Where the emoji search shows its field and results, as the system emoji keyboard's search shows
/// them on a 402-point-wide iPhone, measured with Tools/AppleKeyboardBaseline
/// (`EmojiFrequentlyUsedProbeTests`): the field in the toolbar's row, and while searching a row of
/// results between it and the keys, which makes the keyboard taller.
enum KeyboardEmojiSearchGeometry {
    enum Measured {
        /// From each side of the keyboard to the field.
        static let fieldInset: CGFloat = 9
        static let fieldHeight: CGFloat = 40
        static let fieldCornerRadius: CGFloat = 12
        /// From the field's leading edge to the magnifying glass's center.
        static let magnifierCenter: CGFloat = 28
        /// From the field's leading edge to where its text starts.
        static let textStart: CGFloat = 43.3
        /// From the field's trailing edge to the clear button's center.
        static let clearCenterInset: CGFloat = 15.2
        static let caretWidth: CGFloat = 2
        static let caretHeight: CGFloat = 22
        /// Between the field and the results.
        static let resultsGapBelowField: CGFloat = 6
        static let resultsHeight: CGFloat = 41
        /// Between the results and the tops of the keys as drawn.
        static let resultsGapAboveKeys: CGFloat = 8
        static let resultWidth: CGFloat = 43
        /// From one result's leading edge to the next one's.
        static let resultPitch: CGFloat = 53
        /// From the keyboard's leading edge to the first result.
        static let resultsInset: CGFloat = 8
    }

    /// How much taller the keyboard is while searching: the field keeps the place it has in the
    /// toolbar's row, centered there, and the results come between it and the keys.
    static var addedKeyboardHeight: CGFloat {
        let fieldToKeys = ((KeyboardStyle.buttonSize - Measured.fieldHeight) / 2) + KeyboardStyle.sectionSpacing
        return Measured.resultsGapBelowField + Measured.resultsHeight + Measured.resultsGapAboveKeys - fieldToKeys
    }
}
