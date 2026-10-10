import UIKit
import XCTest

/// Measurement only: types a context and the first letters of a word, then records the
/// labels shown in the keyboard's suggestion bar, the band between the keyboard's top
/// edge and its first row of keys.
///
/// `TEST_RUNNER_PROBE_PLAN` is a JSON array of `{"context": [words], "prefix": letters}`,
/// each optionally with `"text"`, typed first key by key in lowercase, punctuation included;
/// `TEST_RUNNER_PROBE_OUTPUT` receives `[{"context", "prefix", "text", "bar": [labels]}]`.
final class PredictionBarCaptureTests: XCTestCase {
    private struct Probe: Codable {
        let context: [String]
        let prefix: String
        let text: String?
        var bar: [String]?
    }

    func testCapturePredictionBar() throws {
        let environment = ProcessInfo.processInfo.environment
        let planPath = try XCTUnwrap(environment["PROBE_PLAN"], "PROBE_PLAN is not set")
        let outputPath = try XCTUnwrap(environment["PROBE_OUTPUT"], "PROBE_OUTPUT is not set")
        var probes = try JSONDecoder().decode([Probe].self, from: Data(contentsOf: URL(fileURLWithPath: planPath)))
        let customKeyboardMarker = environment["BASELINE_KEYBOARD_MARKER"]

        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        let keyMap: KeyboardKeyMap
        let firstRowKey: XCUIElement
        if let customKeyboardMarker {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: customKeyboardMarker, in: app))
            keyMap = try KeyboardKeyMap(customKeyboardIn: app)
            firstRowKey = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "q")).firstMatch
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
            let keyboard = app.keyboards.element
            keyMap = try KeyboardKeyMap(systemKeyboard: keyboard)
            firstRowKey = keyboard.keys["q"]
        }
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let clear = app.buttons["clear"]
        let bar = SuggestionBarReader(app: app, firstRowKey: firstRowKey)

        /// Types letters, spaces, and punctuation with the keyboard's own keys, punctuation
        /// from its number page, so the keyboard sees the text as typed. (Typing text through
        /// the test bypasses the keyboard's suggestions.)
        func typeKeyByKey(_ text: String) throws {
            for character in text.lowercased() {
                if character == " " {
                    origin.withOffset(CGVector(dx: keyMap.spaceCenter.x, dy: keyMap.spaceCenter.y)).tap()
                } else if character.isLetter {
                    try type(String(character))
                } else {
                    let keyboard = app.keyboards.element
                    let numberPageKey = ["more", "numbers", "123"].map { keyboard.keys[$0] }.first { $0.exists }
                    try XCTUnwrap(numberPageKey, "no key opens the number page").tap()
                    let mark = keyboard.keys[String(character)]
                    XCTAssertTrue(mark.waitForExistence(timeout: 2), "no \(character) key")
                    mark.tap()
                }
            }
        }

        func type(_ letters: String) throws {
            for letter in letters.filter({ $0 != "'" }) {
                let point = try XCTUnwrap(keyMap.point(for: letter, offset: [0, 0]))
                origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
            }
        }

        for index in probes.indices {
            if let text = probes[index].text {
                try typeKeyByKey(text)
            }
            for word in probes[index].context {
                try type(word)
                origin.withOffset(CGVector(dx: keyMap.spaceCenter.x, dy: keyMap.spaceCenter.y)).tap()
            }
            try type(probes[index].prefix)
            Thread.sleep(forTimeInterval: 0.8)
            probes[index].bar = bar.readSettled()
            let data = try JSONEncoder().encode(Array(probes[...index]))
            try data.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            clear.tap()
            input.tap()
        }
    }
}
