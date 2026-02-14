import Foundation
import Testing
@testable import KeyVox

struct ListPatternDetectorTests {
    @Test
    func detectsNumberedListWithLeadIn() {
        let detector = ListPatternDetector()
        let text = "We need three things one get dog food two charge phone three call mom"

        let detected = detector.detectList(in: text)
        #expect(detected != nil)
        #expect(detected?.leadingText == "We need three things")
        #expect(detected?.items.count == 3)
        #expect(detected?.items.map(\.spokenIndex) == [1, 2, 3])
    }

    @Test
    func ignoresSingleMarkerInput() {
        let detector = ListPatternDetector()
        let detected = detector.detectList(in: "one buy groceries")
        #expect(detected == nil)
    }

    @Test
    func ignoresNumericProseThatIsNotMonotonicList() {
        let detector = ListPatternDetector()
        let detected = detector.detectList(in: "Version 1.2.3 shipped on 2026-02-14")
        #expect(detected == nil)
    }

    @Test
    func splitsTrailingCommentaryFromLastListItem() {
        let detector = ListPatternDetector()
        let text = "For today one take the dog out two clean the kitchen three cook dinner tonight and now I can relax"

        let detected = detector.detectList(in: text)
        #expect(detected != nil)
        #expect(detected?.items.count == 3)
        #expect(detected?.trailingText == "I can relax")
    }
}
