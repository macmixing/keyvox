import XCTest

/// Records the system keyboards' layout for the KeyVox emoji keyboard: every element on screen,
/// with its kind, label, and frame, on the system English keyboard and then on the emoji
/// keyboard its Emoji key opens, written as JSON to `EMOJI_PROBE_OUTPUT`, with a screenshot of
/// each next to it. With `EMOJI_PROBE_KEYBOARD_MARKER`, the label of a key only it has, it records
/// that keyboard in place of the system one. It then types the emoji `EMOJI_PROBE_TAP` names (😀
/// by default), deletes, and goes back to the letters, recording the text after each. With
/// `EMOJI_PROBE_BROWSE` set, it first taps every category in the bar, recording the last.
final class EmojiKeyboardProbeTests: XCTestCase {
    private struct Element: Encodable {
        let type: String
        let label: String
        let identifier: String
        let value: String?
        let frame: [CGFloat]
    }

    private struct Screen: Encodable {
        let name: String
        let text: String
        let elements: [Element]
    }

    func testRecordEmojiKeyboardLayout() throws {
        let environment = ProcessInfo.processInfo.environment
        let outputPath = try XCTUnwrap(environment["EMOJI_PROBE_OUTPUT"], "EMOJI_PROBE_OUTPUT is not set")

        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        var screens: [Screen] = []

        func record(_ name: String) throws {
            screens.append(Screen(name: name, text: input.value as? String ?? "", elements: try Self.elements(in: app)))
            let screenshot = URL(fileURLWithPath: outputPath).deletingPathExtension().path + "-\(name).png"
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: screenshot))
        }

        if let marker = environment["EMOJI_PROBE_KEYBOARD_MARKER"] {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: marker, in: app))
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
        }
        Thread.sleep(forTimeInterval: 0.8)
        try record("english")

        let emojiKey = app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Emoji")).firstMatch
        XCTAssertTrue(emojiKey.waitForExistence(timeout: 3), "no Emoji key")
        emojiKey.tap()
        Thread.sleep(forTimeInterval: 1.5)
        try record("emoji")

        func tap(_ labels: [String]) {
            let element = app.descendants(matching: .any).matching(NSPredicate(format: "label IN %@", labels)).firstMatch
            XCTAssertTrue(element.waitForExistence(timeout: 3), "no \(labels)")
            element.tap()
            Thread.sleep(forTimeInterval: 0.8)
        }
        if environment["EMOJI_PROBE_BROWSE"] != nil {
            for category in ["Animals & Nature", "Food & Drink", "Activity", "Travel & Places", "Objects", "Symbols", "Flags", "Smileys & People"] {
                tap(["\(category) category"])
                if category == "Flags" {
                    try record("flags")
                }
            }
        }
        tap([environment["EMOJI_PROBE_TAP"] ?? "😀"])
        try record("typed-emoji")
        tap(["delete", "Delete"])
        try record("deleted")
        tap(["letters", "ABC"])
        try record("letters")

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(screens).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }

    private static func elements(in app: XCUIApplication) throws -> [Element] {
        var elements: [Element] = []
        func collect(_ snapshot: XCUIElementSnapshot) {
            let frame = snapshot.frame
            elements.append(Element(
                type: String(describing: snapshot.elementType.rawValue),
                label: snapshot.label,
                identifier: snapshot.identifier,
                value: snapshot.value.map { String(describing: $0) },
                frame: [frame.minX, frame.minY, frame.width, frame.height]
            ))
            snapshot.children.forEach(collect)
        }
        collect(try app.snapshot())
        return elements
    }
}
