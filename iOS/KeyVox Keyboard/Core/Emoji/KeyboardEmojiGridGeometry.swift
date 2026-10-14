import CoreGraphics

/// Where the emoji page puts its emoji and section titles: columns of emoji filled top to bottom,
/// sections side by side, each with its title above, spaced as on the system emoji keyboard and
/// with as many rows as fit the grid's height at nearly the system's size.
struct KeyboardEmojiGridGeometry: Equatable {
    /// The system emoji keyboard on a 402-point-wide iPhone, in points, measured with
    /// Tools/AppleKeyboardBaseline (`EmojiKeyboardProbeTests`).
    enum Measured {
        static let emojiSize: CGFloat = 32
        static let columnPitch: CGFloat = 46
        /// The first and fifth rows' emoji are 154 points apart.
        static let rowPitch: CGFloat = 38.5
        static let leadingInset: CGFloat = 10
        /// Between a section's last column and the next section's first, beyond a column.
        static let sectionGap: CGFloat = 14
        /// From the top of a section's title to the top of its first row of emoji.
        static let titleHeight: CGFloat = 30
        /// From a section's first column to its title.
        static let titleInset: CGFloat = 2
    }

    /// The smallest share of the system's size rows are drawn at before one fewer row is drawn.
    static let smallestScale: CGFloat = 0.9

    struct Layout: Equatable {
        /// Each section's title frame.
        let titleFrames: [CGRect]
        /// Each section's emoji frames, in order; each covers its share of the grid around its emoji.
        let emojiFrames: [[CGRect]]
        /// Where the grid scrolls to show each section from its start.
        let sectionOffsets: [CGFloat]
        /// Where each section's last emoji ends.
        let sectionEnds: [CGFloat]
        /// How far a title kept at the grid's leading edge sits from it.
        let pinnedTitleInset: CGFloat
        let contentSize: CGSize

        /// Where `section`'s title, `width` wide, shows with the grid scrolled to `offset`: at its
        /// section's start, then kept at the grid's leading edge while the section shows there,
        /// until the section's end pushes it off, as the system keyboard keeps its titles.
        func titleFrame(section: Int, contentOffset offset: CGFloat, width: CGFloat) -> CGRect {
            let start = titleFrames[section]
            let x = max(start.minX, min(offset + pinnedTitleInset, sectionEnds[section] - width))
            return CGRect(x: x, y: start.minY, width: width, height: start.height)
        }
    }

    let rowCount: Int
    let scale: CGFloat

    init(gridHeight: CGFloat) {
        var rowCount = 1
        while Self.height(rowCount: rowCount + 1) * Self.smallestScale <= gridHeight {
            rowCount += 1
        }
        self.rowCount = rowCount
        scale = min(1, gridHeight / Self.height(rowCount: rowCount))
    }

    var emojiSize: CGFloat { Measured.emojiSize * scale }

    /// Frames for sections of `emojiCounts` emoji each.
    func layout(emojiCounts: [Int]) -> Layout {
        let columnPitch = Measured.columnPitch * scale
        let rowPitch = Measured.rowPitch * scale
        let titleHeight = Measured.titleHeight * scale
        var sectionX = Measured.leadingInset * scale
        var titleFrames: [CGRect] = []
        var emojiFrames: [[CGRect]] = []
        var sectionOffsets: [CGFloat] = []
        var sectionEnds: [CGFloat] = []
        for count in emojiCounts {
            sectionOffsets.append(sectionX - (Measured.leadingInset * scale))
            let columns = max(1, Int((Double(count) / Double(rowCount)).rounded(.up)))
            titleFrames.append(CGRect(
                x: sectionX + (Measured.titleInset * scale),
                y: 0,
                width: (CGFloat(columns) * columnPitch) - (Measured.titleInset * scale),
                height: titleHeight
            ))
            emojiFrames.append((0..<count).map { index in
                let centerX = sectionX + (emojiSize / 2) + (CGFloat(index / rowCount) * columnPitch)
                let centerY = titleHeight + (emojiSize / 2) + (CGFloat(index % rowCount) * rowPitch)
                return CGRect(
                    x: centerX - (columnPitch / 2),
                    y: centerY - (rowPitch / 2),
                    width: columnPitch,
                    height: rowPitch
                )
            })
            sectionEnds.append(sectionX + (CGFloat(columns - 1) * columnPitch) + emojiSize)
            sectionX += (CGFloat(columns) * columnPitch) + (Measured.sectionGap * scale)
        }
        let contentWidth = sectionX - (Measured.sectionGap * scale) - columnPitch + emojiSize
            + (Measured.leadingInset * scale)
        return Layout(
            titleFrames: titleFrames,
            emojiFrames: emojiFrames,
            sectionOffsets: sectionOffsets,
            sectionEnds: sectionEnds,
            pinnedTitleInset: (Measured.leadingInset + Measured.titleInset) * scale,
            contentSize: CGSize(width: contentWidth, height: Self.height(rowCount: rowCount) * scale)
        )
    }

    /// The height `rowCount` rows take at the system's size, with the title above them.
    private static func height(rowCount: Int) -> CGFloat {
        Measured.titleHeight + (CGFloat(rowCount - 1) * Measured.rowPitch) + Measured.emojiSize
    }
}
