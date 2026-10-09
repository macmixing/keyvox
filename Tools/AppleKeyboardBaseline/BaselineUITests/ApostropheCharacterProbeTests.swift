import XCTest

/// Measurement only: with smart quotes on, as in Messages, taps the apostrophe key on the number
/// page and the symbol page after each kind of text before the cursor and records the field's
/// text and the page that shows next. Measures the system keyboard, or KeyVox when
/// `TEST_RUNNER_APOSTROPHE_KEYBOARD=KeyVox`. Writes `[{"page", "before", "text", "after"}]`, with
/// text as Unicode scalars, to `TEST_RUNNER_APOSTROPHE_OUTPUT`.
final class ApostropheCharacterProbeTests: XCTestCase {
    private struct Result: Encodable {
        let page: String
        let before: String
        let text: [String]
        let after: String
    }

    /// How the probe finds keys and moves between pages on the keyboard it measures.
    private struct Keyboard {
        let key: (String) -> XCUIElement
        let open: (String) throws -> Void
        let current: () -> String
        let space: String
        let lineBreak: String
        let apostrophe: String
    }

    /// Each kind of character before the cursor, plus a closing mark after a word and a quote
    /// opened earlier in the text, to show whether anything before the last character counts.
    private static let textsBefore = ["", "a", "1", "a ", "a\n", "(", ")", ".", "-", "\"", "$", "'", "a'", "'a "]

    func testProbeApostropheCharacter() throws {
        let environment = ProcessInfo.processInfo.environment
        let outputPath = try XCTUnwrap(environment["APOSTROPHE_OUTPUT"])
        let app = XCUIApplication()
        app.launchEnvironment["DISABLE_AUTOCORRECT"] = "1"
        app.launchEnvironment["SMART_QUOTES"] = "1"
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        let keyboard = try keyboard(named: environment["APOSTROPHE_KEYBOARD"], in: app)

        var results: [Result] = []
        for page in ["numbers", "symbols"] {
            for before in Self.textsBefore {
                app.buttons["clear"].tap()
                try type(before, on: keyboard)
                try keyboard.open(page)
                keyboard.key(keyboard.apostrophe).tap()
                Thread.sleep(forTimeInterval: 0.4)
                results.append(Result(
                    page: page,
                    before: before,
                    text: (input.value as? String ?? "").unicodeScalars.map { String(format: "U+%04X", $0.value) },
                    after: keyboard.current()
                ))
                try JSONEncoder().encode(results).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            }
        }
    }

    private func keyboard(named name: String?, in app: XCUIApplication) throws -> Keyboard {
        if name == "KeyVox" {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: "Space", in: app))
            return Keyboard(
                key: { KeyVoxKeyboardPages.key($0, in: app) },
                open: { try KeyVoxKeyboardPages.open($0, in: app) },
                current: { KeyVoxKeyboardPages.current(app) },
                space: "Space",
                lineBreak: "Return",
                apostrophe: "’"
            )
        }
        XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
        let system = app.keyboards.element
        return Keyboard(
            key: { label in
                let key = system.keys[label].firstMatch
                return key.exists ? key : system.buttons[label].firstMatch
            },
            open: { try SystemKeyboardPages.open($0, on: system) },
            current: { SystemKeyboardPages.current(system) },
            space: "space",
            lineBreak: "return",
            apostrophe: "'"
        )
    }

    /// Types each character from the page that has it; space and return are on every page.
    private func type(_ text: String, on keyboard: Keyboard) throws {
        for character in text {
            let label: String
            switch character {
            case " ":
                label = keyboard.space
            case "\n":
                label = keyboard.lineBreak
            default:
                let page = character.isLetter ? "letters" : "numbers"
                if keyboard.current() != page {
                    try keyboard.open(page)
                }
                label = character == "'" ? keyboard.apostrophe : String(character)
            }
            let key = keyboard.key(label)
            try XCTUnwrap(key.exists ? key : nil, "no key types \(character)").tap()
        }
    }
}
