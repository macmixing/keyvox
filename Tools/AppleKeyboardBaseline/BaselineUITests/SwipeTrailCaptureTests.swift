import XCTest

/// Capture only: swipes words across the third-party keyboard that has a key labeled
/// `TEST_RUNNER_SWIPE_KEYBOARD_MARKER`, for recording how its swipe trail looks.
///
/// `TEST_RUNNER_SWIPE_WORDS` lists the words, comma separated. Each swipe lands on its first
/// letter's key center and moves to each next letter's in a minimum-jerk stroke (slowing into
/// every key, as aimed hand movements do) of 120 ms plus 45 ms per key pitch, given at 20 Hz,
/// then the keyboard rests `TEST_RUNNER_SWIPE_PAUSE` seconds (default 1.2) for the trail to fade.
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

    /// The Simulator plays a synthesized path at the times it gives only when its points are
    /// this sparse; denser paths arrive all at once. The keyboard still sees the screen's own
    /// samples in between.
    private static let samplesPerSecond = 20.0
    private static let strokeBase = 0.12
    private static let strokePerPitch = 0.045

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
            let samples = try path(through: word, keys: keys)
            let start = Date().timeIntervalSince1970
            try SyntheticTouchPath.perform(samples)
            swipes.append(Swipe(word: word, start: start, end: Date().timeIntervalSince1970))
            Thread.sleep(forTimeInterval: pause)
        }
        let output = Output(swipes: swipes, typed: input.value as? String ?? "")
        try JSONEncoder().encode(output).write(to: URL(fileURLWithPath: outputPath))
    }

    /// Screen samples of a swipe of `word` through its letters' key centers.
    private func path(through word: String, keys: KeyboardKeyMap) throws -> [(point: CGPoint, offset: TimeInterval)] {
        let centers = try word.lowercased().map { letter in
            try XCTUnwrap(keys.point(for: letter, offset: [0, 0]), "no key for \(letter)")
        }
        let pitch = try XCTUnwrap(keys.point(for: "w", offset: [0, 0])).x - (try XCTUnwrap(keys.point(for: "q", offset: [0, 0]))).x
        var samples: [(point: CGPoint, offset: TimeInterval)] = [(centers[0], 0)]
        var time = 0.0
        for (from, to) in zip(centers, centers.dropFirst()) {
            let duration = Self.strokeBase + Self.strokePerPitch * hypot(to.x - from.x, to.y - from.y) / pitch
            let steps = max(1, Int((duration * Self.samplesPerSecond).rounded(.up)))
            for step in 1...steps {
                let tau = Double(step) / Double(steps)
                let progress = 10 * pow(tau, 3) - 15 * pow(tau, 4) + 6 * pow(tau, 5)
                samples.append((
                    CGPoint(x: from.x + (to.x - from.x) * progress, y: from.y + (to.y - from.y) * progress),
                    time + duration * tau
                ))
            }
            time += duration
        }
        return samples
    }
}
