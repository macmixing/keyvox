import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import KeyVoxPredictiveKeyboard

/// The swipe gate lets a finger swipe only once it travels far enough, fast enough, alone, and
/// then keeps going or slows into its lift; a finger lifting at speed right after the threshold
/// is a tap when typing goes on (`tap-vs-swipe/README.md`, section 5).
final class SwipeGateTests: XCTestCase {
    private let pitch = 40.0
    private let origin = CGPoint(x: 100, y: 100)
    private let hold = SwipeGate<Int>.standardParameters.holdAfterThreshold

    func testATouchBecomesASwipeOnceItStaysDownPastTheThreshold() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 0.999), time: 10.1))
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 1), time: 10.1), "meeting the threshold is not enough")
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 1.1), time: 10.1 + hold / 2))
        XCTAssertTrue(gate.touchMoved(0, to: point(atPitches: 1.2), time: 10.1 + hold))
        XCTAssertTrue(gate.isSwipe(0))
    }

    func testRightAfterATapTheThresholdStartsAtTwoPitchesAndFallsToOne() {
        for (since, threshold) in [(0.0, 2.0), (0.1, 1.75), (0.2, 1.5), (0.3, 1.25), (0.4, 1.0), (1.0, 1.0)] {
            XCTAssertFalse(becomesSwipe(after: since, reaching: threshold - 0.001), "\(since)")
            // Just past it, since the time since the tap is not exact in binary.
            XCTAssertTrue(becomesSwipe(after: since, reaching: threshold + 1e-9), "\(since)")
        }
    }

    func testASlowSlideStaysATap() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 1.4), time: 11), "1.4 pitches a second")
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 1.4), time: 11 + hold))
        XCTAssertEqual(gate.touchEnded(0, at: point(atPitches: 1.4), time: 11 + hold), .tap)
    }

    func testALiftSlowingIntoTheLastKeyRightAfterTheThresholdIsASwipe() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 0.5), time: 10.05))
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 1.0), time: 10.08))
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 1.02), time: 10.09))
        XCTAssertEqual(gate.touchEnded(0, at: point(atPitches: 1.03), time: 10.1), .swipe)
    }

    func testALiftAtSpeedRightAfterTheThresholdWaitsOnWhatComesNext() {
        var rolled = rollingGate()
        XCTAssertEqual(rolled.settleUndecidedAsTaps(), [0], "a finger landing makes it a tap")
        XCTAssertEqual(rolled.settleUndecided(at: 20), [])

        var alone = rollingGate()
        let window = SwipeGate<Int>.standardParameters.undecidedWindow
        XCTAssertEqual(alone.settleUndecided(at: 10.1 + window / 2), [])
        XCTAssertEqual(alone.settleUndecided(at: 10.1 + window), [0], "no finger landing makes it a swipe")
        XCTAssertEqual(alone.settleUndecidedAsTaps(), [])
    }

    func testATouchLandingBesideAnotherFingerNeverSwipes() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        gate.touchBegan(1, at: origin, time: 10.05, pitch: pitch, isEligible: true)
        XCTAssertFalse(gate.touchMoved(1, to: point(atPitches: 3), time: 10.2))
        XCTAssertFalse(gate.touchMoved(1, to: point(atPitches: 3.5), time: 10.3))
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 3), time: 10.2), "the first finger lost it too")
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 3.5), time: 10.3))
        XCTAssertEqual(gate.touchEnded(0, at: point(atPitches: 3.5), time: 10.3), .tap)
    }

    func testAnotherFingerLandingAfterTheSwipeStartsLeavesIt() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 1.2), time: 10.1))
        XCTAssertTrue(gate.touchMoved(0, to: point(atPitches: 1.5), time: 10.1 + hold))
        gate.touchBegan(1, at: origin, time: 10.2, pitch: pitch, isEligible: true)
        XCTAssertTrue(gate.isSwipe(0))
        XCTAssertFalse(gate.touchMoved(1, to: point(atPitches: 3), time: 10.3))
    }

    func testAnIneligibleTouchNeverSwipes() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: false)
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 3), time: 10.1))
        XCTAssertEqual(gate.touchEnded(0, at: point(atPitches: 3), time: 10.2), .tap)
    }

    /// Whether a touch landing `since` after a tap that moves steadily out to `distance` pitches
    /// and stays there becomes a swipe.
    private func becomesSwipe(after since: TimeInterval, reaching distance: Double) -> Bool {
        var gate = SwipeGate<Int>()
        gate.recordTap(at: 10 - since)
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        _ = gate.touchMoved(0, to: point(atPitches: distance), time: 10.1)
        return gate.touchMoved(0, to: point(atPitches: distance), time: 10.1 + hold)
    }

    /// A gate whose touch rolled past the threshold at constant speed and lifted at once.
    private func rollingGate() -> SwipeGate<Int> {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        _ = gate.touchMoved(0, to: point(atPitches: 0.9), time: 10.08)
        _ = gate.touchMoved(0, to: point(atPitches: 1.0), time: 10.09)
        XCTAssertEqual(gate.touchEnded(0, at: point(atPitches: 1.1), time: 10.1), .undecided)
        return gate
    }

    private func point(atPitches distance: Double) -> CGPoint {
        CGPoint(x: origin.x + distance * pitch * 0.6, y: origin.y + distance * pitch * 0.8)
    }
}
