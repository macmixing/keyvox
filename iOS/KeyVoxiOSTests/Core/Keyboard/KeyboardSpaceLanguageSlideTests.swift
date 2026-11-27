import CoreGraphics
import Testing
@testable import KeyVox_iOS

/// A finger that slides sideways across the space bar switches the language, right to the next and
/// left to the previous; a short or mostly vertical move, or one the cursor trackpad took, does not.
struct KeyboardSpaceLanguageSlideTests {
    private let start = CGPoint(x: 200, y: 20)
    private let travel = KeyboardSpaceLanguageSlide.minimumTravel

    @Test func aSidewaysSlideSwitchesForwardToTheRightAndBackToTheLeft() {
        #expect(KeyboardSpaceLanguageSlide.offset(from: start, to: CGPoint(x: start.x + travel, y: start.y + 5), trackpadWasActive: false) == 1)
        #expect(KeyboardSpaceLanguageSlide.offset(from: start, to: CGPoint(x: start.x - travel, y: start.y - 5), trackpadWasActive: false) == -1)
    }

    @Test func aShortOrMostlyVerticalMoveDoesNotSwitch() {
        #expect(KeyboardSpaceLanguageSlide.offset(from: start, to: CGPoint(x: start.x + travel - 1, y: start.y), trackpadWasActive: false) == nil)
        #expect(KeyboardSpaceLanguageSlide.offset(from: start, to: CGPoint(x: start.x + travel, y: start.y - travel * 2), trackpadWasActive: false) == nil)
        #expect(KeyboardSpaceLanguageSlide.offset(from: start, to: start, trackpadWasActive: false) == nil)
    }

    @Test func aFingerTheTrackpadTookNeverSwitches() {
        #expect(KeyboardSpaceLanguageSlide.offset(from: start, to: CGPoint(x: start.x + travel * 3, y: start.y), trackpadWasActive: true) == nil)
    }

    @Test func aSlideMovesFarEnoughToKeepTheTrackpadHoldFromStarting() {
        #expect(travel > KeyboardSpaceTrackpadConfiguration().activationMovementTolerance)
    }
}
