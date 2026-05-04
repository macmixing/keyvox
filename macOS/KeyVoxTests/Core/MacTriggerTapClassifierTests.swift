import Foundation
import XCTest
@testable import KeyVox

final class MacTriggerTapClassifierTests: XCTestCase {
    func testFirstQuickTapSchedulesSingleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)

        let event = classifier.registerQuickTap(at: Date(timeIntervalSince1970: 10))

        XCTAssertEqual(event, .scheduleSingleTap)
    }

    func testSecondQuickTapInsideWindowProducesDoubleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        _ = classifier.registerQuickTap(at: Date(timeIntervalSince1970: 10))

        let event = classifier.registerQuickTap(at: Date(timeIntervalSince1970: 10.2))

        XCTAssertEqual(event, .doubleTap)
    }

    func testSecondQuickTapOutsideWindowSchedulesNewSingleTap() {
        var classifier = MacTriggerTapClassifier(doubleTapInterval: 0.3)
        _ = classifier.registerQuickTap(at: Date(timeIntervalSince1970: 10))

        let event = classifier.registerQuickTap(at: Date(timeIntervalSince1970: 10.5))

        XCTAssertEqual(event, .scheduleSingleTap)
    }
}
