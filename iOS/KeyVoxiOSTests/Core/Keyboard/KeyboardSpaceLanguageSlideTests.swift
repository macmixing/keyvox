import CoreGraphics
import Testing
@testable import KeyVox_iOS

/// A finger that swipes across the space bar, far enough for the bar's own width, switches the
/// language, right to the next and left to the previous; a short or mostly vertical move, a hold
/// followed by a small move, or a finger the cursor trackpad took, does not, and a finger held
/// still goes into the trackpad.
struct KeyboardSpaceLanguageSlideTests {
    private let start = CGPoint(x: 200, y: 20)
    private let spaceBarWidth: CGFloat = 200
    private var travel: CGFloat { KeyboardSpaceLanguageSlide.minimumTravel(spaceBarWidth: spaceBarWidth) }
    private let tolerance = KeyboardSpaceTrackpadConfiguration().activationMovementTolerance

    private func offset(to end: CGPoint, spaceBarWidth: CGFloat? = nil, trackpadWasActive: Bool = false) -> Int? {
        KeyboardSpaceLanguageSlide.offset(
            from: start,
            to: end,
            spaceBarWidth: spaceBarWidth ?? self.spaceBarWidth,
            trackpadWasActive: trackpadWasActive
        )
    }

    @Test func aSwipeAcrossTheSpaceBarSwitchesForwardToTheRightAndBackToTheLeft() {
        #expect(offset(to: CGPoint(x: start.x + travel, y: start.y + 5)) == 1)
        #expect(offset(to: CGPoint(x: start.x - travel, y: start.y - 5)) == -1)
    }

    @Test func aShortOrMostlyVerticalMoveDoesNotSwitch() {
        #expect(offset(to: CGPoint(x: start.x + travel - 1, y: start.y)) == nil)
        #expect(offset(to: CGPoint(x: start.x - travel + 1, y: start.y)) == nil)
        #expect(offset(to: CGPoint(x: start.x + travel, y: start.y - travel * 2)) == nil)
        #expect(offset(to: start) == nil)
    }

    @Test func theTravelASwipeNeedsFollowsTheSpaceBarsWidth() {
        let end = CGPoint(x: start.x + travel, y: start.y)
        #expect(offset(to: end, spaceBarWidth: spaceBarWidth) == 1)
        #expect(offset(to: end, spaceBarWidth: spaceBarWidth * 2) == nil)
        #expect(offset(to: end, spaceBarWidth: 0) == nil)
    }

    @Test func aFingerTheTrackpadTookNeverSwitches() {
        #expect(offset(to: CGPoint(x: start.x + travel * 3, y: start.y), trackpadWasActive: true) == nil)
    }

    @Test func aFingerHeldStillGoesIntoTheTrackpadAndNeverSwitches() {
        var trackpad = KeyboardSpaceTrackpadSession()
        trackpad.begin(onSpaceKey: true, location: start)
        let held = CGPoint(x: start.x + tolerance, y: start.y)
        _ = trackpad.update(location: held, isStillOnSpaceKey: true)
        let startedTrackpad = trackpad.activate(location: held)
        #expect(startedTrackpad)

        let lifted = CGPoint(x: held.x + travel, y: start.y)
        _ = trackpad.update(location: lifted, isStillOnSpaceKey: true)
        let trackpadWasActive = trackpad.end()
        #expect(offset(to: lifted, trackpadWasActive: trackpadWasActive) == nil)
    }

    @Test func aHoldFollowedByASmallMoveNeverSwitches() {
        var trackpad = KeyboardSpaceTrackpadSession()
        trackpad.begin(onSpaceKey: true, location: start)
        // The finger moves just far enough to keep the trackpad from starting, then stays down.
        let moved = CGPoint(x: start.x + tolerance + 1, y: start.y)
        _ = trackpad.update(location: moved, isStillOnSpaceKey: true)
        let startedTrackpad = trackpad.activate(location: moved)
        #expect(startedTrackpad == false)

        let trackpadWasActive = trackpad.end()
        #expect(tolerance + 1 < travel)
        #expect(offset(to: moved, trackpadWasActive: trackpadWasActive) == nil)
    }

    @Test func aSwipeKeepsTheTrackpadHoldFromStarting() {
        var trackpad = KeyboardSpaceTrackpadSession()
        trackpad.begin(onSpaceKey: true, location: start)
        let swiped = CGPoint(x: start.x + travel, y: start.y)
        _ = trackpad.update(location: swiped, isStillOnSpaceKey: true)
        let startedTrackpad = trackpad.activate(location: swiped)
        #expect(startedTrackpad == false)
        let trackpadWasActive = trackpad.end()
        #expect(offset(to: swiped, trackpadWasActive: trackpadWasActive) == 1)
    }
}
