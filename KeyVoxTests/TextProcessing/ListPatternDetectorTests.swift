import Foundation
import XCTest
@testable import KeyVox

final class ListPatternDetectorTests: XCTestCase {
    func testDetectsNumberedListWithLeadIn() {
        let detector = ListPatternDetector()
        let text = "We need three things one get dog food two charge phone three call mom"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.leadingText == "We need three things")
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2, 3])
    }

    func testIgnoresSingleMarkerInput() {
        let detector = ListPatternDetector()
        let detected = detector.detectList(in: "one buy groceries")
        XCTAssertTrue(detected == nil)
    }

    func testIgnoresNumericProseThatIsNotMonotonicList() {
        let detector = ListPatternDetector()
        let detected = detector.detectList(in: "Version 1.2.3 shipped on 2026-02-14")
        XCTAssertTrue(detected == nil)
    }

    func testSplitsTrailingCommentaryFromLastListItem() {
        let detector = ListPatternDetector()
        let text = "For today one take the dog out two clean the kitchen three cook dinner tonight and now I can relax"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.trailingText == "and now I can relax")
    }

    func testSplitsCommaAndContinuationFromLastListItem() {
        let detector = ListPatternDetector()
        let text = "Okay so one when I make a list two it formats it properly three when I end the list, and everything's done"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.items.last?.content == "when I end the list")
        XCTAssertTrue(detected?.trailingText == "and everything's done")
    }

    func testPreservesCausalTransitionWhenSplittingLastItem() {
        let detector = ListPatternDetector()
        let text = "Today one get dog food two charge phone three call mom because we leave early"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.items.last?.content == "call mom")
        XCTAssertTrue(detected?.trailingText == "because we leave early")
    }

    func testPreservesAndBecauseTransitionWhenSplittingLastItem() {
        let detector = ListPatternDetector()
        let text = "Today one get dog food two charge phone three call mom and because we leave early"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 3)
        XCTAssertTrue(detected?.items.last?.content == "call mom")
        XCTAssertTrue(detected?.trailingText == "and because we leave early")
    }

    func testDetectsRestartedOneMarkersAcrossParagraphBreaks() {
        let detector = ListPatternDetector()
        let text = """
        For this trip:

        one pack charger

        one pack toothbrush

        one pack socks
        """

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2, 3])
        XCTAssertTrue(detected?.items.map(\.content) == ["pack charger", "pack toothbrush", "pack socks"])
    }

    func testDoesNotDetectRestartedOneMarkersWithoutParagraphBreaks() {
        let detector = ListPatternDetector()
        let text = "one pack charger one pack toothbrush one pack socks"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected == nil)
    }

    func testPreservesParagraphBreaksInTrailingCommentary() {
        let detector = ListPatternDetector()
        let text = """
        Today one get dog food two charge phone three call mom and now this is important.

        This is still part of trailing commentary.
        """

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(
            detected?.trailingText
                == "and now this is important.\n\nThis is still part of trailing commentary."
        )
    }

    func testPrefersExplicitListMarkersOverIncidentalProseNumbers() {
        let detector = ListPatternDetector()
        let text = "This one is kind of interesting. It starts out probably about two months ago. One, Cueboard, Two, KeyVox"

        let detected = detector.detectList(in: text)
        XCTAssertTrue(detected != nil)
        XCTAssertTrue(detected?.items.count == 2)
        XCTAssertTrue(detected?.items.map(\.spokenIndex) == [1, 2])
        XCTAssertTrue(detected?.items.map(\.content) == ["Cueboard", "KeyVox"])
    }
}
