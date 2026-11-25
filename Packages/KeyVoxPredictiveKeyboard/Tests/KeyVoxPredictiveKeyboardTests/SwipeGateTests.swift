import XCTest
#if canImport(CoreGraphics)
import CoreGraphics
#endif
@testable import KeyVoxPredictiveKeyboard

/// The swipe gate lets a finger swipe only once it travels far enough, fast enough, alone
/// (`tap-vs-swipe/README.md`, section 5).
final class SwipeGateTests: XCTestCase {
    private let pitch = 40.0
    private let origin = CGPoint(x: 100, y: 100)

    func testATouchBecomesASwipeExactlyAtOneKeyPitchAtRest() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 0.999), time: 10.1))
        XCTAssertTrue(gate.touchMoved(0, to: point(atPitches: 1), time: 10.1))
        XCTAssertTrue(gate.isSwipe(0))
    }

    func testRightAfterATapTheThresholdStartsAtTwoPitchesAndFallsToOne() {
        for (since, threshold) in [(0.0, 2.0), (0.1, 1.75), (0.2, 1.5), (0.3, 1.25), (0.4, 1.0), (1.0, 1.0)] {
            var gate = SwipeGate<Int>()
            gate.recordTap(at: 10 - since)
            gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
            XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: threshold - 0.001), time: 10.1), "\(since)")
            // Just past it, since the time since the tap is not exact in binary.
            XCTAssertTrue(gate.touchMoved(0, to: point(atPitches: threshold + 1e-9), time: 10.1), "\(since)")
        }
    }

    func testASlowSlideStaysATap() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 1.4), time: 11), "1.4 pitches a second")
        XCTAssertTrue(gate.touchMoved(0, to: point(atPitches: 1.5), time: 11), "1.5 pitches a second")
    }

    func testATouchLandingBesideAnotherFingerNeverSwipes() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        gate.touchBegan(1, at: origin, time: 10.05, pitch: pitch, isEligible: true)
        XCTAssertFalse(gate.touchMoved(1, to: point(atPitches: 3), time: 10.2))
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 3), time: 10.2), "the first finger lost it too")
    }

    func testAnotherFingerLandingAfterTheSwipeStartsLeavesIt() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: true)
        XCTAssertTrue(gate.touchMoved(0, to: point(atPitches: 1.2), time: 10.1))
        gate.touchBegan(1, at: origin, time: 10.2, pitch: pitch, isEligible: true)
        XCTAssertTrue(gate.isSwipe(0))
        XCTAssertFalse(gate.touchMoved(1, to: point(atPitches: 3), time: 10.3))
    }

    func testAnIneligibleTouchNeverSwipes() {
        var gate = SwipeGate<Int>()
        gate.touchBegan(0, at: origin, time: 10, pitch: pitch, isEligible: false)
        XCTAssertFalse(gate.touchMoved(0, to: point(atPitches: 3), time: 10.1))
    }

    private func point(atPitches distance: Double) -> CGPoint {
        CGPoint(x: origin.x + distance * pitch * 0.6, y: origin.y + distance * pitch * 0.8)
    }
}
