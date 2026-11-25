import XCTest

/// Validation only: for each case, clears the text, types the words before it by tapping the
/// third-party keyboard's keys (the one with a key labeled `TEST_RUNNER_SWIPE_KEYBOARD_MARKER`),
/// swipes the case's keys (`SwipeGesturePath`), and records the text the keyboard left.
///
/// `TEST_RUNNER_SWIPE_CASES` is a JSON array of `{"before", "keys", "loops"}`: the words before,
/// space separated (empty for a sentence start), the keys to swipe through, and the indices of
/// the keys to loop around. `TEST_RUNNER_SWIPE_OUTPUT` receives the cases with `typed`, the
/// text after each swipe.
final class SwipeWordsValidationTests: XCTestCase {
    private struct Case: Codable {
        let before: String
        let keys: String
        let loops: [Int]
        var start: [Double]?
        var typed: String?
    }

    func testSwipeCases() throws {
        let environment = ProcessInfo.processInfo.environment
        let marker = try XCTUnwrap(environment["SWIPE_KEYBOARD_MARKER"], "SWIPE_KEYBOARD_MARKER is not set")
        let casesJSON = try XCTUnwrap(environment["SWIPE_CASES"], "SWIPE_CASES is not set")
        let outputPath = try XCTUnwrap(environment["SWIPE_OUTPUT"], "SWIPE_OUTPUT is not set")
        var cases = try JSONDecoder().decode([Case].self, from: Data(casesJSON.utf8))

        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: marker, in: app))
        try KeyVoxKeyboardPages.open("letters", in: app)
        Thread.sleep(forTimeInterval: 1)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let clear = app.buttons["clear"]

        for index in cases.indices {
            clear.tap()
            Thread.sleep(forTimeInterval: 0.6)
            for word in cases[index].before.split(separator: " ") {
                let keys = try KeyboardKeyMap(customKeyboardIn: app)
                for letter in word.lowercased() {
                    let point = try XCTUnwrap(keys.point(for: letter, offset: [0, 0]))
                    origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
                }
                origin.withOffset(CGVector(dx: keys.spaceCenter.x, dy: keys.spaceCenter.y)).tap()
            }
            Thread.sleep(forTimeInterval: 0.6)
            let keys = try KeyboardKeyMap(customKeyboardIn: app)
            let samples = try SwipeGesturePath.samples(
                through: cases[index].keys, loopingAt: Set(cases[index].loops), on: keys
            )
            cases[index].start = [samples[0].point.x, samples[0].point.y]
            try SyntheticTouchPath.perform(samples)
            Thread.sleep(forTimeInterval: 1.2)
            cases[index].typed = input.value as? String ?? ""
            try JSONEncoder().encode(cases).write(to: URL(fileURLWithPath: outputPath))
        }
    }
}
