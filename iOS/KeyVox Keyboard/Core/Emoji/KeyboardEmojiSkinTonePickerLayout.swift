import CoreGraphics

/// Where the skin-tone picker of a held emoji shows its parts, as the system emoji keyboard shows
/// them: a panel centered on the row above the emoji, which stays in view below it, holding the
/// emoji as it comes, a divider, and its skin tones, in a row. Measured on a 402-point-wide iPhone
/// with Tools/AppleKeyboardBaseline (`EmojiFrequentlyUsedProbeTests`).
struct KeyboardEmojiSkinTonePickerLayout: Equatable {
    enum Measured {
        static let panelWidth: CGFloat = 287
        static let panelHeight: CGFloat = 57.3
        /// From the panel's top down to the row of choices.
        static let choiceDrop: CGFloat = 28
        /// From the panel's leading edge to each part's center.
        static let firstChoiceCenter: CGFloat = 26.3
        static let dividerCenter: CGFloat = 53.5
        static let firstToneCenter: CGFloat = 81.8
        static let tonePitch: CGFloat = 44.2
        static let dividerHeight: CGFloat = 30.7
        static let highlightSize: CGFloat = 37
    }

    private let emojiCenter: CGPoint
    let panelFrame: CGRect
    let dividerFrame: CGRect
    /// The center of each choice: the emoji as it comes, then each skin tone.
    let choiceCenters: [CGPoint]

    /// - Parameters:
    ///   - emojiCenter: The held emoji's center.
    ///   - toneCount: How many skin tones the emoji comes in.
    ///   - width: How wide the space the picker shows in is; the panel stays inside it.
    ///   - rowPitch: From one row of emoji to the next.
    init(emojiCenter: CGPoint, toneCount: Int, width: CGFloat, rowPitch: CGFloat) {
        self.emojiCenter = emojiCenter
        let left = min(max(0, emojiCenter.x - (Measured.panelWidth / 2)), max(0, width - Measured.panelWidth))
        // Nothing shows above the space the picker shows in, so a panel that would rise past its
        // top comes down to it.
        let top = max(0, emojiCenter.y - rowPitch - (Measured.panelHeight / 2))
        panelFrame = CGRect(
            x: left,
            y: top,
            width: Measured.panelWidth,
            height: Measured.panelHeight
        )
        let choiceY = top + Measured.choiceDrop
        dividerFrame = CGRect(
            x: left + Measured.dividerCenter - 0.5,
            y: choiceY - (Measured.dividerHeight / 2),
            width: 1,
            height: Measured.dividerHeight
        )
        choiceCenters = [CGPoint(x: left + Measured.firstChoiceCenter, y: choiceY)]
            + (0..<toneCount).map { CGPoint(x: left + Measured.firstToneCenter + (CGFloat($0) * Measured.tonePitch), y: choiceY) }
    }

    /// The choice the finger at `point` is on: the nearest across the panel once the finger is
    /// above the held emoji, none while it is still on the emoji or outside the panel's sides. The
    /// system keyboard was seen choosing nothing for a finger left on the emoji and the tone under a
    /// finger in the panel; how far around the panel a finger still chooses was not measured.
    func choice(at point: CGPoint) -> Int? {
        guard point.x >= panelFrame.minX, point.x <= panelFrame.maxX,
              point.y < emojiCenter.y - (Measured.highlightSize / 2),
              point.y >= panelFrame.minY - Measured.panelHeight else {
            return nil
        }
        return choiceCenters.indices.min { abs(choiceCenters[$0].x - point.x) < abs(choiceCenters[$1].x - point.x) }
    }
}
