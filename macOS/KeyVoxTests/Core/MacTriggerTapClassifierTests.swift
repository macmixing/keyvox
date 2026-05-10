import Foundation
import XCTest
@testable import KeyVox

final class MacTriggerTapClassifierTests: XCTestCase {
    func testFirstQuickTapSchedulesSingleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)

        let event = classifier.registerQuickTap(at: 10)

        XCTAssertEqual(event, .scheduleSingleTap)
    }

    func testSecondQuickTapInsideWindowProducesDoubleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        _ = classifier.registerQuickTap(at: 10)

        let event = classifier.registerQuickTap(at: 10.2)

        XCTAssertEqual(event, .doubleTap)
    }

    func testAwaitingSecondTapOnlyAppliesInsideDoubleTapWindow() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)

        XCTAssertFalse(classifier.isAwaitingSecondTap(at: 10))

        _ = classifier.registerQuickTap(at: 10)

        XCTAssertTrue(classifier.isAwaitingSecondTap(at: 10.2))
        XCTAssertFalse(classifier.isAwaitingSecondTap(at: 10.5))
    }

    func testSecondQuickTapOutsideWindowSchedulesNewSingleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        _ = classifier.registerQuickTap(at: 10)

        let event = classifier.registerQuickTap(at: 10.5)

        XCTAssertEqual(event, .scheduleSingleTap)
    }

    func testTapAfterDoubleTapResetsState() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        _ = classifier.registerQuickTap(at: 10)
        XCTAssertEqual(classifier.registerQuickTap(at: 10.2), .doubleTap)

        let event = classifier.registerQuickTap(at: 10.2)

        XCTAssertEqual(event, .scheduleSingleTap)
    }
}
