import XCTest
@testable import KeyVoxPredictiveKeyboard

/// How long a turned-down correction stays off, as measured on the system keyboard: one
/// rejection for a day, each further one four times as long, up to 180 days.
final class CorrectionRejectionsTests: XCTestCase {
    private let day: TimeInterval = 24 * 60 * 60
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testEachRejectionHoldsBackFourTimesAsLongUpTo180Days() {
        let expectedDays: [Int: Double] = [1: 1, 2: 4, 3: 16, 4: 64, 5: 180, 10: 180]
        for (count, days) in expectedDays {
            XCTAssertEqual(CorrectionRejections.holdDuration(afterRejections: count), days * day, "\(count) rejections")
        }
        XCTAssertEqual(CorrectionRejections.holdDuration(afterRejections: 0), 0)
    }

    func testRejectionHoldsBackUntilItsTimeRunsOut() {
        for count in 1...5 {
            var rejections = CorrectionRejections()
            for _ in 0..<count {
                rejections.recordRejection(of: "the", typed: "teh", at: start)
            }
            let hold = CorrectionRejections.holdDuration(afterRejections: count)
            XCTAssertTrue(rejections.holdsBack("the", of: "teh", at: start.addingTimeInterval(hold - 60)), "\(count)")
            XCTAssertFalse(restarted(rejections).holdsBack("the", of: "teh", at: start.addingTimeInterval(hold)), "\(count)")
        }
    }

    func testUndoHoldsBackOnlyWhileTheKeyboardRuns() {
        var rejections = CorrectionRejections()
        rejections.recordUndo(of: "the", typed: "teh")
        XCTAssertTrue(rejections.holdsBack("the", of: "teh", at: start.addingTimeInterval(365 * day)))
        XCTAssertFalse(restarted(rejections).holdsBack("the", of: "teh", at: start))
    }

    func testChoosingTheCorrectionLetsItApplyAgain() {
        var rejections = CorrectionRejections()
        rejections.recordRejection(of: "the", typed: "teh", at: start)
        rejections.recordAcceptance(of: "the", typed: "teh")
        XCTAssertFalse(rejections.holdsBack("the", of: "teh", at: start))
        rejections.recordRejection(of: "the", typed: "teh", at: start)
        XCTAssertEqual(rejections.rejections[CorrectionRejections.Pair(typed: "teh", correction: "the")]?.count, 1)
    }

    func testOnlyTheTurnedDownCorrectionIsHeldBackWhateverItsCapitals() {
        var rejections = CorrectionRejections()
        rejections.recordRejection(of: "The", typed: "Teh", at: start)
        XCTAssertTrue(rejections.holdsBack("the", of: "teh", at: start))
        XCTAssertFalse(rejections.holdsBack("tech", of: "teh", at: start))
        XCTAssertEqual(rejections.corrections(heldBackFor: "TEH", at: start), ["the"])
    }

    /// The same rejections after the keyboard restarts: saved, without what was only undone.
    private func restarted(_ rejections: CorrectionRejections) -> CorrectionRejections {
        CorrectionRejections(rejections: rejections.rejections)
    }
}
