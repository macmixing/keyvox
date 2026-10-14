import CoreGraphics
import Testing
@testable import KeyVox_iOS

/// A held search result's skin-tone picker sits where the system emoji keyboard's search put it
/// when watched holding the first and the second result, and a tap chooses as it did.
struct KeyboardEmojiSearchSkinTonePickerLayoutTests {
    private typealias Measured = KeyboardEmojiSearchSkinTonePickerLayout.Measured
    private let keyboard = CGRect(x: 0, y: 0, width: 402, height: 400)

    @Test func thePanelLinesUpWithTheStemOfTheFirstResult() {
        let held = CGRect(x: 8, y: 300, width: 43, height: 41)
        let layout = KeyboardEmojiSearchSkinTonePickerLayout(heldResult: held, toneCount: 5, keyboard: keyboard)

        #expect(layout.panelFrame.minX == layout.stemFrame.minX)
        #expect(layout.panelFrame.minY == held.minY - Measured.panelRise)
        #expect(layout.stemFrame.maxY == held.maxY - Measured.stemInset)
        #expect(layout.choiceCenters.count == 6)
    }

    @Test func thePanelKeepsToTheKeyboardsSideOverTheSecondResult() {
        let held = CGRect(x: 61, y: 300, width: 43, height: 41)
        let layout = KeyboardEmojiSearchSkinTonePickerLayout(heldResult: held, toneCount: 5, keyboard: keyboard)

        #expect(layout.panelFrame.minX == Measured.sideInset)
    }

    @Test func thePanelCentersOverAResultAwayFromTheSides() {
        let held = CGRect(x: 180, y: 300, width: 43, height: 41)
        let layout = KeyboardEmojiSearchSkinTonePickerLayout(heldResult: held, toneCount: 5, keyboard: keyboard)

        #expect(abs(layout.panelFrame.midX - held.midX) < 0.001)
    }

    @Test func thePanelComesNoHigherThanTheKeyboardsTop() {
        let held = CGRect(x: 8, y: 40, width: 43, height: 41)
        let layout = KeyboardEmojiSearchSkinTonePickerLayout(heldResult: held, toneCount: 5, keyboard: keyboard)

        #expect(layout.panelFrame.minY == keyboard.minY)
        #expect(layout.stemFrame.minY == layout.panelFrame.maxY)
    }

    @Test func aTapInThePanelChoosesTheNearestAndOneOutsideChoosesNothing() {
        let held = CGRect(x: 180, y: 300, width: 43, height: 41)
        let layout = KeyboardEmojiSearchSkinTonePickerLayout(heldResult: held, toneCount: 5, keyboard: keyboard)

        let second = layout.choiceCenters[2]
        #expect(layout.choice(tappedAt: CGPoint(x: second.x + 5, y: second.y)) == 2)
        #expect(layout.choice(tappedAt: CGPoint(x: second.x, y: layout.panelFrame.minY - 1)) == nil)
        #expect(layout.choice(tappedAt: CGPoint(x: held.midX, y: held.midY)) == nil)
    }
}
