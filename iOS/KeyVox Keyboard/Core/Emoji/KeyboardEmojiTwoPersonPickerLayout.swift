import CoreGraphics

/// Where the skin-tone picker of a held two-person emoji shows its parts, as the system emoji
/// keyboard shows them: a panel centered over the emoji, joined to it by a stem as wide as the
/// emoji, holding a row of the first person's tones, a row of the second person's, a divider, and
/// below it the emoji as it comes and the version chosen so far. Measured on a 402-point-wide
/// iPhone with Tools/AppleKeyboardBaseline (`EmojiFrequentlyUsedProbeTests`), from the emoji's
/// center. The system panel may reach above the keyboard; this one stays inside the space it shows
/// in, and drops its stem when that moves it onto the emoji.
struct KeyboardEmojiTwoPersonPickerLayout: Equatable {
    enum Measured {
        static let panelWidth: CGFloat = 248
        static let panelHeight: CGFloat = 200
        /// From the emoji's center up to the panel's top.
        static let panelRise: CGFloat = 232.67
        /// How close the panel comes to the sides of the space it shows in.
        static let sideInset: CGFloat = 6
        static let stemWidth: CGFloat = 35.3
        /// From the emoji's center down to the stem's bottom.
        static let stemDrop: CGFloat = 18
        /// From the panel's top down to each row's center.
        static let firstRowDrop: CGFloat = 36.67
        static let secondRowDrop: CGFloat = 86.67
        static let dividerDrop: CGFloat = 120
        static let bottomRowDrop: CGFloat = 164
        static let tonePitch: CGFloat = 44
        /// From the panel's center to the emoji as it comes and to the chosen version.
        static let bottomOffset: CGFloat = 55
        static let dividerInset: CGFloat = 13.5
        static let dividerHeight: CGFloat = 1
        static let highlightSize: CGFloat = 40
        /// The bottom row's emoji are this much larger than the rows'.
        static let bottomEmojiScale: CGFloat = 1.5
    }

    /// What a tap in the picker lands on.
    enum Target: Equatable {
        case firstTone(Int)
        case secondTone(Int)
        /// The emoji as it comes.
        case plain
        /// The version chosen so far.
        case chosen
        /// The panel's background, between its parts.
        case panel
    }

    let panelFrame: CGRect
    /// None when the panel had to move down onto the emoji.
    let stemFrame: CGRect?
    let dividerFrame: CGRect
    let firstToneCenters: [CGPoint]
    let secondToneCenters: [CGPoint]
    let plainCenter: CGPoint
    let chosenCenter: CGPoint
    /// How much the picker's sizes shrink, below 1 under Display Zoom.
    let sizeScale: CGFloat

    /// - Parameters:
    ///   - emojiCenter: The held emoji's center.
    ///   - bounds: The space the picker shows in; the panel stays inside it.
    ///   - sizeScale: How much the picker's sizes shrink, below 1 under Display Zoom.
    init(emojiCenter: CGPoint, bounds: CGRect, sizeScale: CGFloat = 1) {
        self.sizeScale = sizeScale
        let left = min(
            max(bounds.minX + Measured.sideInset * sizeScale, emojiCenter.x - (Measured.panelWidth * sizeScale / 2)),
            bounds.maxX - Measured.sideInset * sizeScale - Measured.panelWidth * sizeScale
        )
        let top = max(bounds.minY, emojiCenter.y - Measured.panelRise * sizeScale)
        panelFrame = CGRect(x: left, y: top, width: Measured.panelWidth * sizeScale, height: Measured.panelHeight * sizeScale)
        let stemBottom = emojiCenter.y + Measured.stemDrop * sizeScale
        stemFrame = top == emojiCenter.y - Measured.panelRise * sizeScale
            ? CGRect(
                x: emojiCenter.x - (Measured.stemWidth * sizeScale / 2),
                y: panelFrame.maxY,
                width: Measured.stemWidth * sizeScale,
                height: stemBottom - panelFrame.maxY
            )
            : nil
        dividerFrame = CGRect(
            x: left + Measured.dividerInset * sizeScale,
            y: top + Measured.dividerDrop * sizeScale - (Measured.dividerHeight * sizeScale / 2),
            width: Measured.panelWidth * sizeScale - (Measured.dividerInset * sizeScale * 2),
            height: Measured.dividerHeight * sizeScale
        )
        let centerX = panelFrame.midX
        let toneXs = (0..<5).map { centerX + (CGFloat($0 - 2) * Measured.tonePitch * sizeScale) }
        firstToneCenters = toneXs.map { CGPoint(x: $0, y: top + Measured.firstRowDrop * sizeScale) }
        secondToneCenters = toneXs.map { CGPoint(x: $0, y: top + Measured.secondRowDrop * sizeScale) }
        plainCenter = CGPoint(x: centerX - Measured.bottomOffset * sizeScale, y: top + Measured.bottomRowDrop * sizeScale)
        chosenCenter = CGPoint(x: centerX + Measured.bottomOffset * sizeScale, y: top + Measured.bottomRowDrop * sizeScale)
    }

    /// What a tap at `point` lands on: the nearest tone in the row it is in, or the bottom row's
    /// half it is in; the panel itself between them, and nothing outside the panel.
    func target(at point: CGPoint) -> Target? {
        guard panelFrame.contains(point) || stemFrame?.contains(point) == true else { return nil }
        let half = Measured.highlightSize * sizeScale / 2
        func nearestTone(in centers: [CGPoint]) -> Int? {
            guard abs(point.y - centers[0].y) <= half else { return nil }
            return centers.indices.min { abs(centers[$0].x - point.x) < abs(centers[$1].x - point.x) }
        }
        if let tone = nearestTone(in: firstToneCenters) {
            return .firstTone(tone)
        }
        if let tone = nearestTone(in: secondToneCenters) {
            return .secondTone(tone)
        }
        if point.y > dividerFrame.maxY, point.y <= panelFrame.maxY {
            return point.x < panelFrame.midX ? .plain : .chosen
        }
        return .panel
    }
}
