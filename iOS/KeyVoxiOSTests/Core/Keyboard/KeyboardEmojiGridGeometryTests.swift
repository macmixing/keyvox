import CoreGraphics
import Testing
@testable import KeyVox_iOS

/// The emoji grid is spaced as on the system emoji keyboard and draws as many of its rows as fit.
struct KeyboardEmojiGridGeometryTests {
    private typealias Measured = KeyboardEmojiGridGeometry.Measured

    private static func height(rowCount: Int) -> CGFloat {
        CGFloat(rowCount) * Measured.emojiSize
    }

    private static func isClose(_ value: CGFloat, _ expected: CGFloat) -> Bool {
        abs(value - expected) < 0.001
    }

    @Test func theSystemsRowsDrawAtItsSizeWhenTheyFit() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: Measured.maximumRowCount))
        #expect(geometry.rowCount == Measured.maximumRowCount)
        #expect(geometry.scale == 1)
    }

    @Test func aShorterGridDrawsFewerRowsAtTheSystemsSize() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: Measured.maximumRowCount) - 1)
        #expect(geometry.rowCount == Measured.maximumRowCount - 1)
        #expect(geometry.scale == 1)
    }

    @Test func aTallerGridStillDrawsTheSystemsRows() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: Measured.maximumRowCount + 2))
        #expect(geometry.rowCount == Measured.maximumRowCount)
        #expect(geometry.scale == 1)
    }

    @Test func aGridTooShortForOneRowDrawsItSmaller() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: 1) / 2)
        #expect(geometry.rowCount == 1)
        #expect(geometry.scale == 0.5)
    }

    @Test func rowsShareTheHeightLeftAboveEachRow() {
        let leftOver: CGFloat = 40
        let gridHeight = Self.height(rowCount: Measured.maximumRowCount) + leftOver
        let geometry = KeyboardEmojiGridGeometry(gridHeight: gridHeight)
        let gap = leftOver / CGFloat(Measured.maximumRowCount)
        #expect(Self.isClose(geometry.rowGap, gap))
        #expect(Self.isClose(geometry.rowPitch, Measured.emojiSize + gap))

        let frames = geometry.layout(emojiCounts: [geometry.rowCount]).emojiFrames[0]
        #expect(Self.isClose(frames[0].midY - Measured.emojiSize / 2, gap))
        #expect(Self.isClose(frames[geometry.rowCount - 1].midY + Measured.emojiSize / 2, gridHeight))
    }

    @Test func emojiFillColumnsTopToBottomAtTheSystemsSpacing() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: Measured.maximumRowCount))
        let frames = geometry.layout(emojiCounts: [geometry.rowCount + 1]).emojiFrames[0]

        #expect(Self.isClose(frames[0].midX - Measured.emojiSize / 2, Measured.leadingInset))
        #expect(frames[1].midX == frames[0].midX)
        #expect(Self.isClose(frames[geometry.rowCount].midX - frames[0].midX, Measured.columnPitch))
        #expect(frames[geometry.rowCount].midY == frames[0].midY)
    }

    @Test func theGridComesToRestWithTheNearestColumnAtTheSystemsResting() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: Measured.maximumRowCount))
        let layout = geometry.layout(emojiCounts: [geometry.rowCount * 10, geometry.rowCount * 10])
        let column = layout.emojiFrames[1][geometry.rowCount * 3].midX - Measured.emojiSize / 2
        let resting = column - Measured.leadingInset

        for nudge: CGFloat in [-Measured.columnPitch / 3, 0, Measured.columnPitch / 3] {
            let rest = layout.restingContentOffset(near: resting + nudge, maximum: .greatestFiniteMagnitude)
            #expect(Self.isClose(rest, resting))
        }
    }

    @Test func theGridRestsWithinItsStartAndEnd() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: Measured.maximumRowCount))
        let layout = geometry.layout(emojiCounts: [geometry.rowCount * 10])
        let maximum = layout.contentSize.width / 2

        #expect(layout.restingContentOffset(near: 1, maximum: maximum) == 0)
        #expect(layout.restingContentOffset(near: maximum + Measured.columnPitch, maximum: maximum) == maximum)
    }

    @Test func eachSectionStartsAColumnAndAGapAfterTheOneBefore() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: Measured.maximumRowCount))
        let layout = geometry.layout(emojiCounts: [geometry.rowCount * 2, 1])

        let lastOfFirst = layout.emojiFrames[0].last!
        let firstOfSecond = layout.emojiFrames[1][0]
        #expect(Self.isClose(firstOfSecond.midX - lastOfFirst.midX, Measured.columnPitch + Measured.sectionGap))
        #expect(Self.isClose(
            layout.sectionOffsets[1],
            firstOfSecond.midX - Measured.emojiSize / 2 - Measured.leadingInset
        ))
    }
}
