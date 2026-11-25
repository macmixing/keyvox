import XCTest

/// Validation only: for each case, clears the text, types the words before it by tapping the
/// keyboard's keys, swipes the case's keys (`SwipeGesturePath`), and records the text the keyboard
/// left and its suggestion bar.
///
/// The keyboard is the third-party one with a key labeled `TEST_RUNNER_SWIPE_KEYBOARD_MARKER`, or
/// the system keyboard when `TEST_RUNNER_SWIPE_SYSTEM_KEYBOARD` is 1.
/// `TEST_RUNNER_SWIPE_CASES` is a JSON array of `{"before", "keys", "loops"}`: the words before,
/// space separated (empty for a sentence start), the keys to swipe through, and the indices of
/// the keys to loop around, with an optional `"loop"` (`SwipeGesturePath.Loop`) shaping the loop.
/// `TEST_RUNNER_SWIPE_OUTPUT` receives the cases with `typed`, the
/// text after each swipe, `bar`, the suggestion bar's entries then, and `path`, the points sent;
/// `TEST_RUNNER_SWIPE_SCREENSHOTS`, when set, is a folder that receives a screenshot of each.
final class SwipeWordsValidationTests: XCTestCase {
    private struct Case: Codable {
        let before: String
        let keys: String
        let loops: [Int]
        var loop: SwipeGesturePath.Loop?
        var start: [Double]?
        /// The points sent, as screen x, y and seconds from the touch landing.
        var path: [[Double]]?
        var typed: String?
        var bar: [String]?
    }

    func testSwipeCases() throws {
        let environment = ProcessInfo.processInfo.environment
        let usesSystemKeyboard = environment["SWIPE_SYSTEM_KEYBOARD"] == "1"
        let marker = environment["SWIPE_KEYBOARD_MARKER"]
        XCTAssertTrue(usesSystemKeyboard || marker != nil, "SWIPE_KEYBOARD_MARKER is not set")
        let screenshots = environment["SWIPE_SCREENSHOTS"]
        let casesJSON = try XCTUnwrap(environment["SWIPE_CASES"], "SWIPE_CASES is not set")
        let outputPath = try XCTUnwrap(environment["SWIPE_OUTPUT"], "SWIPE_OUTPUT is not set")
        var cases = try JSONDecoder().decode([Case].self, from: Data(casesJSON.utf8))

        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        if usesSystemKeyboard {
            // Picked from the globe's menu where there is one, as a person picks it.
            let globe = app.buttons["Next keyboard"]
            if globe.waitForExistence(timeout: 2) {
                globe.press(forDuration: 1.2)
                let english = app.cells.matching(NSPredicate(format: "label BEGINSWITH %@", "English")).firstMatch
                if english.waitForExistence(timeout: 3) { english.tap() }
            }
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: marker ?? "", in: app))
            try KeyVoxKeyboardPages.open("letters", in: app)
        }
        Thread.sleep(forTimeInterval: 1)
        func keyMap() throws -> KeyboardKeyMap {
            usesSystemKeyboard
                ? try KeyboardKeyMap(systemKeyboard: app.keyboards.element)
                : try KeyboardKeyMap(customKeyboardIn: app)
        }
        func firstRowKey() -> XCUIElement {
            let labels = NSPredicate(format: "label IN %@", ["q", "Q"])
            if usesSystemKeyboard { return app.keyboards.keys.matching(labels).firstMatch }
            return app.descendants(matching: .any).matching(labels).allElementsBoundByIndex
                .max { $0.frame.midY < $1.frame.midY } ?? app.descendants(matching: .any).matching(labels).firstMatch
        }
        keep(XCUIScreen.main.screenshot(), named: "0-keyboard", in: screenshots)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let clear = app.buttons["clear"]

        for index in cases.indices {
            clear.tap()
            Thread.sleep(forTimeInterval: 0.6)
            for word in cases[index].before.split(separator: " ") {
                let keys = try keyMap()
                for letter in word.lowercased() {
                    let point = try XCTUnwrap(keys.point(for: letter, offset: [0, 0]))
                    origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
                }
                origin.withOffset(CGVector(dx: keys.spaceCenter.x, dy: keys.spaceCenter.y)).tap()
            }
            Thread.sleep(forTimeInterval: 0.6)
            let keys = try keyMap()
            let samples = try SwipeGesturePath.samples(
                through: cases[index].keys, loopingAt: Set(cases[index].loops), loop: cases[index].loop ?? .init(), on: keys
            )
            cases[index].start = [samples[0].point.x, samples[0].point.y]
            cases[index].path = samples.map { [$0.point.x, $0.point.y, $0.offset] }
            try SyntheticTouchPath.perform(samples)
            Thread.sleep(forTimeInterval: 1.2)
            cases[index].typed = input.value as? String ?? ""
            cases[index].bar = SuggestionBarReader(app: app, firstRowKey: firstRowKey()).readSettled()
            let name = "\(index + 1)-\(cases[index].before.isEmpty ? "start" : cases[index].before.replacingOccurrences(of: " ", with: "_"))-\(cases[index].keys)-\(cases[index].loops.isEmpty ? "plain" : "loop")"
            keep(XCUIScreen.main.screenshot(), named: name, in: screenshots)
            // On a device the output path is the device's own, so each result is in the log too.
            print("SWIPE_CASE_RESULT " + String(decoding: try JSONEncoder().encode(cases[index]), as: UTF8.self))
            try? JSONEncoder().encode(cases).write(to: URL(fileURLWithPath: outputPath))
        }
    }

    /// Keeps `screenshot` in the test's results, and as a PNG in `folder` when one is given.
    private func keep(_ screenshot: XCUIScreenshot, named name: String, in folder: String?) {
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let folder {
            try? screenshot.pngRepresentation.write(to: URL(fileURLWithPath: folder).appendingPathComponent(name + ".png"))
        }
    }
}
