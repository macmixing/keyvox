import CoreGraphics

/// Where the emoji page puts its emoji: columns of emoji filled top to bottom, sections side by side,
/// spaced as on the system emoji keyboard, which titles no section; as many rows as fit the grid's
/// height at the system's size, up to its four, with the height left over shared equally above each
/// row; a grid too short for one row draws it smaller.
struct KeyboardEmojiGridGeometry: Equatable {
    /// The system emoji keyboard on a 390-point-wide iPhone 13 Pro, in points, measured from its
    /// screenshots (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`).
    enum Measured {
        static let emojiSize: CGFloat = 38
        static let columnPitch: CGFloat = 53.2
        static let maximumRowCount = 4
        /// From the grid's leading edge to its first column; once the grid stops scrolling, a
        /// column always rests here too.
        static let leadingInset: CGFloat = 14.7
        /// Between a section's last column and the next section's first, beyond a column.
        static let sectionGap: CGFloat = 23
    }

    struct Layout: Equatable {
        /// Each section's emoji frames, in order; each covers its share of the grid around its emoji.
        let emojiFrames: [[CGRect]]
        /// Where the grid scrolls to show each section from its start.
        let sectionOffsets: [CGFloat]
        /// Where each column's emoji start, in order.
        let columnStarts: [CGFloat]
        /// How far from the grid's leading edge a column rests once the grid stops scrolling.
        let restingColumnInset: CGFloat
        let contentSize: CGSize

        /// Where the grid comes to rest when scrolling would stop at `proposed`: with the column
        /// nearest there resting its inset from the leading edge, as the system keyboard's grid
        /// does, kept between the grid's start and `maximum`.
        func restingContentOffset(near proposed: CGFloat, maximum: CGFloat) -> CGFloat {
            guard let column = columnStarts.min(by: {
                abs($0 - restingColumnInset - proposed) < abs($1 - restingColumnInset - proposed)
            }) else {
                return proposed
            }
            return min(max(column - restingColumnInset, 0), maximum)
        }
    }

    let rowCount: Int
    let scale: CGFloat
    /// Above each row's emoji: its share of the height the rows leave.
    let rowGap: CGFloat
    /// From one row's emoji to the next one's.
    let rowPitch: CGFloat
    /// The grid's height, which its content never exceeds, so the grid never scrolls up and down.
    let gridHeight: CGFloat

    init(gridHeight: CGFloat) {
        self.gridHeight = gridHeight
        let fittingRowCount = Int((gridHeight / Measured.emojiSize).rounded(.down))
        rowCount = min(Measured.maximumRowCount, max(1, fittingRowCount))
        scale = min(1, gridHeight / (CGFloat(rowCount) * Measured.emojiSize))
        rowGap = max(0, gridHeight - (CGFloat(rowCount) * Measured.emojiSize * scale)) / CGFloat(rowCount)
        rowPitch = (Measured.emojiSize * scale) + rowGap
    }

    var emojiSize: CGFloat { Measured.emojiSize * scale }

    /// `count` emoji rounded up to whole columns, so a section's last column is full.
    func wholeColumnsCount(_ count: Int) -> Int {
        Int((Double(count) / Double(rowCount)).rounded(.up)) * rowCount
    }

    /// Frames for sections of `emojiCounts` emoji each.
    func layout(emojiCounts: [Int]) -> Layout {
        let columnPitch = Measured.columnPitch * scale
        let leadingInset = Measured.leadingInset * scale
        var sectionX = leadingInset
        var emojiFrames: [[CGRect]] = []
        var sectionOffsets: [CGFloat] = []
        var columnStarts: [CGFloat] = []
        for count in emojiCounts {
            sectionOffsets.append(sectionX - leadingInset)
            let columns = max(1, Int((Double(count) / Double(rowCount)).rounded(.up)))
            emojiFrames.append((0..<count).map { index in
                let centerX = sectionX + (emojiSize / 2) + (CGFloat(index / rowCount) * columnPitch)
                let centerY = rowGap + (emojiSize / 2) + (CGFloat(index % rowCount) * rowPitch)
                return CGRect(
                    x: centerX - (columnPitch / 2),
                    y: centerY - (rowPitch / 2),
                    width: columnPitch,
                    height: rowPitch
                )
            })
            columnStarts += (0..<columns).map { sectionX + (CGFloat($0) * columnPitch) }
            sectionX += (CGFloat(columns) * columnPitch) + (Measured.sectionGap * scale)
        }
        let contentWidth = sectionX - (Measured.sectionGap * scale) - columnPitch + emojiSize + leadingInset
        return Layout(
            emojiFrames: emojiFrames,
            sectionOffsets: sectionOffsets,
            columnStarts: columnStarts,
            restingColumnInset: leadingInset,
            contentSize: CGSize(
                width: contentWidth,
                height: min(gridHeight, (CGFloat(rowCount) * rowPitch))
            )
        )
    }
}
