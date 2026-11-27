import XCTest

/// Capture only: swipes words across the third-party keyboard that has a key labeled
/// `TEST_RUNNER_SWIPE_KEYBOARD_MARKER`, for recording how its swipe trail looks.
///
/// `TEST_RUNNER_SWIPE_WORDS` lists the words, comma separated. Each swipe lands on its first
/// letter's key center and moves through each next letter's (`SwipeGesturePath`), then the
/// keyboard rests `TEST_RUNNER_SWIPE_PAUSE` seconds (default 1.2) for the trail to fade.
/// `TEST_RUNNER_SWIPE_OUTPUT` receives `{"swipes": [{"word", "start", "end"}], "typed"}`, where
/// `start` and `end` are each swipe's wall-clock times in seconds since 1970, for picking frames
/// of a screen recording, and `typed` is the text the swipes left.
final class SwipeTrailCaptureTests: XCTestCase {
    private struct Swipe: Encodable {
        let word: String
        let start: Double
        let end: Double
    }

    private struct Output: Encodable {
        let swipes: [Swipe]
        let typed: String
    }

    func testSwipeWords() throws {
        let environment = ProcessInfo.processInfo.environment
        let marker = try XCTUnwrap(environment["SWIPE_KEYBOARD_MARKER"], "SWIPE_KEYBOARD_MARKER is not set")
        let words = try XCTUnwrap(environment["SWIPE_WORDS"], "SWIPE_WORDS is not set").split(separator: ",").map(String.init)
        let outputPath = try XCTUnwrap(environment["SWIPE_OUTPUT"], "SWIPE_OUTPUT is not set")
        let pause = environment["SWIPE_PAUSE"].flatMap(Double.init) ?? 1.2

        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: marker, in: app))
        try KeyVoxKeyboardPages.open("letters", in: app)
        Thread.sleep(forTimeInterval: 1)
        let keys = try KeyboardKeyMap(customKeyboardIn: app)

        var swipes: [Swipe] = []
        for word in words {
            let samples = try SwipeGesturePath.samples(through: word, on: keys)
            let start = Date().timeIntervalSince1970
            try SyntheticTouchPath.perform(samples)
            swipes.append(Swipe(word: word, start: start, end: Date().timeIntervalSince1970))
            Thread.sleep(forTimeInterval: pause)
        }
        let output = Output(swipes: swipes, typed: input.value as? String ?? "")
        try JSONEncoder().encode(output).write(to: URL(fileURLWithPath: outputPath))
    }
}
