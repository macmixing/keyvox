import UIKit
import XCTest

/// Replays a KeyVox typing plan on a keyboard and records what ends up in the text field
/// after each sentence.
///
/// Run through `xcodebuild test` with `TEST_RUNNER_BASELINE_PLAN` and
/// `TEST_RUNNER_BASELINE_OUTPUT` set to host paths (see README.md). The system keyboard
/// is used unless `TEST_RUNNER_BASELINE_KEYBOARD_MARKER` names a key label that only a
/// third-party keyboard has, in which case the replay switches to that keyboard, and taps
/// the key labeled `TEST_RUNNER_BASELINE_KEYBOARD_LETTERS_KEY`, if set, to show its letters.
final class AppleKeyboardBaselineTests: XCTestCase {
    func testReplayTypingPlan() throws {
        let environment = ProcessInfo.processInfo.environment
        let planPath = try XCTUnwrap(environment["BASELINE_PLAN"], "BASELINE_PLAN is not set")
        let outputPath = try XCTUnwrap(environment["BASELINE_OUTPUT"], "BASELINE_OUTPUT is not set")
        let customKeyboardMarker = environment["BASELINE_KEYBOARD_MARKER"]
        let plan = try BaselinePlan.load(from: planPath)
        let writer = BaselineResultsWriter(
            path: outputPath,
            device: environment["SIMULATOR_DEVICE_NAME"] ?? UIDevice.current.model,
            systemVersion: UIDevice.current.systemVersion,
            keyboard: environment["BASELINE_KEYBOARD_NAME"] ?? "System"
        )

        let app = XCUIApplication()
        if environment["BASELINE_DISABLE_AUTOCORRECT"] == "1" {
            app.launchEnvironment["DISABLE_AUTOCORRECT"] = "1"
        }
        if environment["BASELINE_AUTOCAPITALIZE"] == "1" {
            app.launchEnvironment["AUTOCAPITALIZE"] = "1"
        }
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        let keyMap: KeyboardKeyMap
        if let customKeyboardMarker {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: customKeyboardMarker, in: app))
            if let lettersKey = environment["BASELINE_KEYBOARD_LETTERS_KEY"], lettersKey.isEmpty == false {
                app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", lettersKey)).firstMatch.tap()
            }
            keyMap = try KeyboardKeyMap(customKeyboardIn: app)
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
            let keyboard = app.keyboards.element
            keyMap = try KeyboardKeyMap(systemKeyboard: keyboard)
        }
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
