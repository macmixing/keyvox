import CoreGraphics

/// Where the skin-tone picker of a held search result shows its parts, as the system emoji
/// keyboard's search shows them: a panel above the results, joined to the held result by a stem
/// that covers it, holding the emoji as it comes, a divider, and its skin tones, in a row. The panel
/// centers over the result as far as the keyboard's sides allow, and lines up with the stem's side
/// where the stem would otherwise meet its rounded corner. Measured on a 402-point-wide iPhone with
/// Tools/AppleKeyboardBaseline (`EmojiFrequentlyUsedProbeTests`), holding the first and the second
/// result, from the held result's frame. The system's panel rises past the top of the keyboard;
/// another maker's keyboard draws nothing outside itself, so here the panel comes no higher than the
/// keyboard's top.
struct KeyboardEmojiSearchSkinTonePickerLayout: Equatable {
    enum Measured {
        static let panelWidth: CGFloat = 289.67
        static let panelHeight: CGFloat = 55
        /// From the held result's top up to the panel's top.
        static let panelRise: CGFloat = 63.67
        /// From the panel's top down to the row of choices.
        static let choiceDrop: CGFloat = 27.6
        /// From each side of the keyboard to the panel, at the most.
        static let sideInset: CGFloat = 0.67
        /// How far inside the held result the stem's sides and bottom sit.
        static let stemInset: CGFloat = 0.67
        static let panelCornerRadius: CGFloat = 11
        static let stemCornerRadius: CGFloat = 5.5
        /// From the panel's leading edge to each part's center.
        static let firstChoiceCenter: CGFloat = 24.83
        static let dividerCenter: CGFloat = 54.83
        static let firstToneCenter: CGFloat = 84.83
        static let tonePitch: CGFloat = 45
        static let dividerWidth: CGFloat = 1
        static let dividerHeight: CGFloat = 36.7
    }

    let panelFrame: CGRect
    let stemFrame: CGRect
    let dividerFrame: CGRect
    /// The center of each choice: the emoji as it comes, then each skin tone.
    let choiceCenters: [CGPoint]
    /// How much the picker's sizes shrink, below 1 under Display Zoom.
    let sizeScale: CGFloat

    /// - Parameters:
    ///   - heldResult: The held result's frame.
    ///   - toneCount: How many skin tones the emoji comes in.
    ///   - keyboard: The keyboard's bounds.
    ///   - sizeScale: How much the picker's sizes shrink, below 1 under Display Zoom.
    init(heldResult: CGRect, toneCount: Int, keyboard: CGRect, sizeScale: CGFloat = 1) {
        self.sizeScale = sizeScale
        let width = keyboard.width
        let top = max(keyboard.minY, heldResult.minY - Measured.panelRise * sizeScale)
        stemFrame = CGRect(
            x: heldResult.minX + Measured.stemInset * sizeScale,
            y: top + Measured.panelHeight * sizeScale,
            width: heldResult.width - (Measured.stemInset * sizeScale * 2),
            height: heldResult.maxY - Measured.stemInset * sizeScale - (top + Measured.panelHeight * sizeScale)
        )
        var left = min(
            max(Measured.sideInset * sizeScale, heldResult.midX - (Measured.panelWidth * sizeScale / 2)),
            width - Measured.sideInset * sizeScale - Measured.panelWidth * sizeScale
        )
        if stemFrame.minX - left < Measured.panelCornerRadius * sizeScale {
            left = stemFrame.minX
        } else if left + Measured.panelWidth * sizeScale - stemFrame.maxX < Measured.panelCornerRadius * sizeScale {
            left = stemFrame.maxX - Measured.panelWidth * sizeScale
        }
        panelFrame = CGRect(x: left, y: top, width: Measured.panelWidth * sizeScale, height: Measured.panelHeight * sizeScale)
        let choiceY = top + Measured.choiceDrop * sizeScale
        dividerFrame = CGRect(
            x: left + Measured.dividerCenter * sizeScale - (Measured.dividerWidth * sizeScale / 2),
            y: choiceY - (Measured.dividerHeight * sizeScale / 2),
            width: Measured.dividerWidth * sizeScale,
            height: Measured.dividerHeight * sizeScale
        )
        choiceCenters = [CGPoint(x: left + Measured.firstChoiceCenter * sizeScale, y: choiceY)]
            + (0..<toneCount).map { CGPoint(x: left + Measured.firstToneCenter * sizeScale + (CGFloat($0) * Measured.tonePitch * sizeScale), y: choiceY) }
    }

    /// The choice a tap at `point` picks: the nearest, for a tap in the panel. The system keyboard
    /// was seen typing the tone tapped and nothing for a tap outside the panel.
    func choice(tappedAt point: CGPoint) -> Int? {
        guard panelFrame.contains(point) else { return nil }
        return choiceCenters.indices.min { abs(choiceCenters[$0].x - point.x) < abs(choiceCenters[$1].x - point.x) }
    }
}
