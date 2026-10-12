import XCTest

/// Measurement only: presses and holds keys on the system keyboard, or on the third-party keyboard
/// that has a key labeled `TEST_RUNNER_KEY_HOLD_KEYBOARD_MARKER` when that is set, and records
/// what each hold typed, to measure the characters a held key offers and how the finger picks one.
///
/// `TEST_RUNNER_KEY_HOLD_SCRIPT` names a file holding a JSON array of holds, or
/// `TEST_RUNNER_KEY_HOLD_SCRIPT_JSON` holds the array itself. Each hold is
/// `{"page", "key", "seconds", "beforeType"?, "tapBarAt"?, "shift"?, "dx"?, "dy"?, "velocity"?,
/// "thenHold"?, "thenType"?}`: after tapping the letter keys of `beforeType` and then the
/// suggestion bar's entry at `tapBarAt`, counted from the left, on `page` ("letters", "numbers",
/// or "symbols"), after tapping shift when `shift` is true, presses the key labeled `key` for
/// `seconds`, then, when `dx` or `dy` is set, slides that many points from the key's center, at
/// `velocity` points a second or slowly, and stays there for `thenHold` seconds before lifting,
/// then taps the keys labeled with the characters of `thenType`. Set
/// `TEST_RUNNER_KEY_HOLD_SMART_QUOTES=1` to turn the text view's smart quotes on, and
/// `TEST_RUNNER_KEY_HOLD_LANDSCAPE=1` to hold the keys in landscape; the device turns back upright
/// after.
///
/// Each hold starts on empty text, except where the keyboard covers the app's clear button, as a
/// tall keyboard on its side does, when `textBefore` holds the text it started on.
///
/// `TEST_RUNNER_KEY_HOLD_OUTPUT` receives `[{"hold", "textBefore", "typed", "start", "end",
/// "keyFrame", "keyboardFrame"}]`, rewritten after every hold, where `start` and `end` are the hold's
/// wall-clock times in seconds since 1970, for matching screenshots taken while it lasted, and the
/// frames are in screen points.
final class KeyHoldProbeTests: XCTestCase {
    private struct Hold: Codable {
        let page: String
        let key: String
        let seconds: Double
        let beforeType: String?
        let tapBarAt: Int?
        let shift: Bool?
        let dx: Double?
        let dy: Double?
        let velocity: Double?
        let thenHold: Double?
        let thenType: String?
    }

    private struct Result: Encodable {
        let hold: Hold
        let textBefore: String
        let typed: String
        let start: Double
        let end: Double
        let keyFrame: CGRect
        let keyboardFrame: CGRect
    }

    /// Finds the keyboard's keys and moves it between pages, for whichever keyboard is showing.
    private struct KeyFinder {
        let key: (String) -> XCUIElement
        let open: (String) throws -> Void
        let shiftLabel: String
        /// The keyboard's frame, or for a third-party keyboard its space key's.
        let frame: () -> CGRect
    }

    func testProbeKeyHolds() throws {
        let environment = ProcessInfo.processInfo.environment
        let script: Data
        if let inline = environment["KEY_HOLD_SCRIPT_JSON"] {
            script = Data(inline.utf8)
        } else {
            let scriptPath = try XCTUnwrap(environment["KEY_HOLD_SCRIPT"], "KEY_HOLD_SCRIPT or KEY_HOLD_SCRIPT_JSON is not set")
            script = try Data(contentsOf: URL(fileURLWithPath: scriptPath))
        }
        let outputPath = try XCTUnwrap(environment["KEY_HOLD_OUTPUT"], "KEY_HOLD_OUTPUT is not set")
        let holds = try JSONDecoder().decode([Hold].self, from: script)

        let app = XCUIApplication()
        if environment["KEY_HOLD_SMART_QUOTES"] == "1" {
            app.launchEnvironment["SMART_QUOTES"] = "1"
        }
        app.launch()
        if environment["KEY_HOLD_LANDSCAPE"] == "1" {
            XCUIDevice.shared.orientation = .landscapeLeft
        }
        defer { XCUIDevice.shared.orientation = .portrait }
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        let keys: KeyFinder
        if let marker = environment["KEY_HOLD_KEYBOARD_MARKER"] {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: marker, in: app))
            keys = KeyFinder(
                key: { KeyVoxKeyboardPages.key($0, in: app) },
                open: { try KeyVoxKeyboardPages.open($0, in: app) },
                shiftLabel: "Shift",
                frame: { app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Space")).firstMatch.frame }
            )
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
            let keyboard = app.keyboards.element
            keys = KeyFinder(
                key: { keyboard.keys[$0].firstMatch },
                open: { try SystemKeyboardPages.open($0, on: keyboard) },
                shiftLabel: "shift",
                frame: { keyboard.frame }
            )
        }

        var results: [Result] = []
        for (index, hold) in holds.enumerated() {
            let context = "hold \(index): \(hold.key)"
            if app.buttons["clear"].isHittable {
                app.buttons["clear"].tap()
                input.tap()
            }
            try keys.open("letters")
            for character in hold.beforeType ?? "" {
                keys.key(String(character)).tap()
            }
            if let index = hold.tapBarAt {
                let bar = SuggestionBarReader(app: app, firstRowKey: keys.key("q"))
                let entries = bar.readSettled()
                let label = try XCTUnwrap(entries.indices.contains(index) ? entries[index] : nil, "\(context): bar is \(entries)")
                let entry = try XCTUnwrap(
                    app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label))
                        .allElementsBoundByIndex.map(\.frame).first(where: bar.contains),
                    "\(context): no bar entry \(label)"
                )
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: entry.midX, dy: entry.midY)).tap()
                Thread.sleep(forTimeInterval: 0.3)
            }
            try keys.open(hold.page)
            if hold.shift == true {
                keys.key(keys.shiftLabel).tap()
                Thread.sleep(forTimeInterval: 0.3)
            }
            let key = keys.key(hold.key)
            guard key.exists else {
                XCTFail("\(context): no such key")
                continue
            }
            let keyFrame = key.frame
            let textBefore = input.value as? String ?? ""
            let center = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            let start = Date().timeIntervalSince1970
            if hold.dx != nil || hold.dy != nil {
                center.press(
                    forDuration: hold.seconds,
                    thenDragTo: center.withOffset(CGVector(dx: hold.dx ?? 0, dy: hold.dy ?? 0)),
                    withVelocity: hold.velocity.map { XCUIGestureVelocity(CGFloat($0)) } ?? .slow,
                    thenHoldForDuration: hold.thenHold ?? 0.3
                )
            } else {
                center.press(forDuration: hold.seconds)
            }
            let end = Date().timeIntervalSince1970
            Thread.sleep(forTimeInterval: 0.4)
            for character in hold.thenType ?? "" {
                keys.key(String(character)).tap()
            }
            results.append(Result(
                hold: hold,
                textBefore: textBefore,
                typed: input.value as? String ?? "",
                start: start,
                end: end,
                keyFrame: keyFrame,
                keyboardFrame: keys.frame()
            ))
            try JSONEncoder().encode(results).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        }
    }
}
