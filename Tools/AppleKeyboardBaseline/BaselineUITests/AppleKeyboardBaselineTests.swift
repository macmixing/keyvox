import UIKit
import XCTest

/// Replays a KeyVox typing plan on the system keyboard and records what ends up in the
/// text field after each sentence.
///
/// Run through `xcodebuild test` with `TEST_RUNNER_BASELINE_PLAN` and
/// `TEST_RUNNER_BASELINE_OUTPUT` set to host paths (see README.md).
final class AppleKeyboardBaselineTests: XCTestCase {
    func testReplayTypingPlan() throws {
        let environment = ProcessInfo.processInfo.environment
        let planPath = try XCTUnwrap(environment["BASELINE_PLAN"], "BASELINE_PLAN is not set")
        let outputPath = try XCTUnwrap(environment["BASELINE_OUTPUT"], "BASELINE_OUTPUT is not set")
        let plan = try BaselinePlan.load(from: planPath)
        let writer = BaselineResultsWriter(
            path: outputPath,
            device: environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion
        )

        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        let keyboard = app.keyboards.element
        XCTAssertTrue(keyboard.waitForExistence(timeout: 15))
        let keyMap = try KeyboardKeyMap(keyboard: keyboard)
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let clear = app.buttons["clear"]

        var recorded: [String] = []
        for sentence in plan.sentences {
            for (word, taps) in zip(sentence.words, sentence.taps) {
                for (letter, offset) in zip(word.filter { $0 != "'" }, taps) {
                    let point = try XCTUnwrap(keyMap.point(for: letter, offset: offset))
                    origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
                }
                origin.withOffset(CGVector(dx: keyMap.spaceCenter.x, dy: keyMap.spaceCenter.y)).tap()
            }
            recorded.append(input.value as? String ?? "")
            try writer.write(recorded)
            clear.tap()
        }
    }
}
