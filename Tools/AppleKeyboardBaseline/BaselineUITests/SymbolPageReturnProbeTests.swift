import XCTest

/// Measurement only: taps every key on the system keyboard's number page and symbol page and
/// records which page shows after each, reopening the page when a key left it. Writes
/// `[{"page", "key", "after"}]` to `TEST_RUNNER_SYMBOL_RETURN_OUTPUT`.
final class SymbolPageReturnProbeTests: XCTestCase {
    private struct Result: Encodable {
        let page: String
        let key: String
        let after: String
    }

    private static let controlKeys: Set<String> = [
        "delete", "space", "return", "shift", "more", "letters", "numbers", "symbols", "Next keyboard",
        "dictation", "emoji", "ABC", "123", "#+=", "Dictate", "Emoji",
    ]

    func testProbeSymbolPageReturn() throws {
        let outputPath = try XCTUnwrap(ProcessInfo.processInfo.environment["SYMBOL_RETURN_OUTPUT"])
        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 5))
        input.tap()
        XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
        let keyboard = app.keyboards.element

        var results: [Result] = []
        for page in ["numbers", "symbols"] {
            try SystemKeyboardPages.open(page, on: keyboard)
            XCTAssertEqual(SystemKeyboardPages.current(keyboard), page)
            // Spacer elements pad the rows and type nothing.
            let labels = keyboard.keys.allElementsBoundByIndex.map(\.label)
                .filter { Self.controlKeys.contains($0) == false && $0.isEmpty == false && $0.hasPrefix("Padding") == false }
            for label in Set(labels).sorted() {
                if SystemKeyboardPages.current(keyboard) != page {
                    try SystemKeyboardPages.open(page, on: keyboard)
                }
                let key = keyboard.keys[label].firstMatch
                guard key.exists else { continue }
                key.tap()
                Thread.sleep(forTimeInterval: 0.4)
                results.append(Result(page: page, key: label, after: SystemKeyboardPages.current(keyboard)))
                try JSONEncoder().encode(results).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            }
        }
    }
}
