import CoreGraphics
import Testing
@testable import KeyVox_iOS

/// The emoji grid is spaced as on the system emoji keyboard and draws as many rows as fit.
struct KeyboardEmojiGridGeometryTests {
    private typealias Measured = KeyboardEmojiGridGeometry.Measured

    private static func height(rowCount: Int) -> CGFloat {
        Measured.titleHeight + (CGFloat(rowCount - 1) * Measured.rowPitch) + Measured.emojiSize
    }

    @Test func theSystemKeyboardsHeightDrawsItsRowsAtItsSize() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: 5))
        #expect(geometry.rowCount == 5)
        #expect(geometry.scale == 1)
    }

    @Test func aShorterGridDrawsFewerRowsAtNearlyTheSystemsSize() {
        let height = Self.height(rowCount: 5) * KeyboardEmojiGridGeometry.smallestScale - 1
        let geometry = KeyboardEmojiGridGeometry(gridHeight: height)
        #expect(geometry.rowCount == 4)
        #expect(geometry.scale >= KeyboardEmojiGridGeometry.smallestScale)
        #expect(geometry.scale <= 1)
    }

    @Test func emojiFillColumnsTopToBottomAtTheSystemsSpacing() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: 5))
        let frames = geometry.layout(emojiCounts: [geometry.rowCount + 1]).emojiFrames[0]

        #expect(frames[0].midX - Measured.emojiSize / 2 == Measured.leadingInset)
        #expect(frames[0].midY - Measured.emojiSize / 2 == Measured.titleHeight)
        #expect(frames[1].midY - frames[0].midY == Measured.rowPitch)
        #expect(frames[geometry.rowCount].midX - frames[0].midX == Measured.columnPitch)
        #expect(frames[geometry.rowCount].midY == frames[0].midY)
    }

    @Test func aSectionsTitleStaysAtTheLeadingEdgeUntilTheSectionsEndPushesItOff() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: 5))
        let layout = geometry.layout(emojiCounts: [geometry.rowCount * 10, 1])
        let start = layout.titleFrames[0]
        let width: CGFloat = 60
        let pinnedInset = Measured.leadingInset + Measured.titleInset

        #expect(layout.titleFrame(section: 0, contentOffset: 0, width: width).minX == start.minX)
        #expect(layout.titleFrame(section: 0, contentOffset: 100, width: width).minX == 100 + pinnedInset)
        let pastTheEnd = layout.sectionEnds[0] + 50
        #expect(layout.titleFrame(section: 0, contentOffset: pastTheEnd, width: width).maxX == layout.sectionEnds[0])
    }

    @Test func eachSectionStartsAColumnAndAGapAfterTheOneBefore() {
        let geometry = KeyboardEmojiGridGeometry(gridHeight: Self.height(rowCount: 5))
        let layout = geometry.layout(emojiCounts: [geometry.rowCount * 2, 1])

        let lastOfFirst = layout.emojiFrames[0].last!
        let firstOfSecond = layout.emojiFrames[1][0]
        #expect(firstOfSecond.midX - lastOfFirst.midX == Measured.columnPitch + Measured.sectionGap)
        #expect(layout.sectionOffsets[1] == firstOfSecond.midX - Measured.emojiSize / 2 - Measured.leadingInset)
        #expect(layout.titleFrames[1].minX == firstOfSecond.midX - Measured.emojiSize / 2 + Measured.titleInset)
    }
}
