import CoreGraphics
import Testing
@testable import KeyVox_iOS

/// A held emoji's skin-tone picker sits where the system emoji keyboard puts it, and the finger
/// chooses as it did when watched.
struct KeyboardEmojiSkinTonePickerLayoutTests {
    private typealias Measured = KeyboardEmojiSkinTonePickerLayout.Measured
    private let width: CGFloat = 402
    private let rowPitch: CGFloat = 53

    @Test func thePanelCentersOverTheEmojiWithItsChoicesInARow() {
        let center = CGPoint(x: 200, y: 600)
        let layout = KeyboardEmojiSkinTonePickerLayout(emojiCenter: center, toneCount: 5, width: width, rowPitch: rowPitch)

        #expect(layout.panelFrame.midX == center.x)
        #expect(abs(layout.panelFrame.midY - (center.y - rowPitch)) < 0.001)
        #expect(layout.choiceCenters.count == 6)
        #expect(layout.choiceCenters.allSatisfy { $0.y == layout.panelFrame.minY + Measured.choiceDrop })
        #expect(abs(layout.choiceCenters[2].x - layout.choiceCenters[1].x - Measured.tonePitch) < 0.001)
    }

    @Test func thePanelStaysInsideTheKeyboardNearItsEdges() {
        let left = KeyboardEmojiSkinTonePickerLayout(emojiCenter: CGPoint(x: 20, y: 600), toneCount: 5, width: width, rowPitch: rowPitch)
        let right = KeyboardEmojiSkinTonePickerLayout(emojiCenter: CGPoint(x: width - 20, y: 600), toneCount: 5, width: width, rowPitch: rowPitch)
        #expect(left.panelFrame.minX == 0)
        #expect(right.panelFrame.maxX == width)
    }

    @Test func aFingerStillOnTheEmojiChoosesNothingAndOneInThePanelChoosesTheNearest() {
        let center = CGPoint(x: 200, y: 600)
        let layout = KeyboardEmojiSkinTonePickerLayout(emojiCenter: center, toneCount: 5, width: width, rowPitch: rowPitch)

        #expect(layout.choice(at: center) == nil)
        let third = layout.choiceCenters[3]
        #expect(layout.choice(at: CGPoint(x: third.x + 5, y: third.y)) == 3)
        #expect(layout.choice(at: CGPoint(x: layout.panelFrame.minX - 10, y: third.y)) == nil)
    }
}
