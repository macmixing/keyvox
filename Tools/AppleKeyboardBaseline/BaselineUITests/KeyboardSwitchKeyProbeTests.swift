import XCTest

/// Records how a person moves on to the next keyboard on this iPhone, by watching it: with the
/// text view focused, saves a screenshot and every labeled element on screen, with its type and
/// frame, then taps the element labeled "Next keyboard" and does the same for the keyboard that
/// shows, `KEYBOARD_SWITCH_ROUNDS` times (4 unless set), or until no such element shows, closing
/// the system's tip on switching keyboards when it shows. Writes
/// each round's screenshot and elements next to `KEYBOARD_SWITCH_OUTPUT`.
final class KeyboardSwitchKeyProbeTests: XCTestCase {
    func testRecordNextKeyboardKey() throws {
        let environment = ProcessInfo.processInfo.environment
        let outputSetting = try XCTUnwrap(environment["KEYBOARD_SWITCH_OUTPUT"], "KEYBOARD_SWITCH_OUTPUT is not set")
        // On a phone, a name without a folder lands in the runner's temporary folder, to copy back.
        let outputPath = outputSetting.hasPrefix("/") ? outputSetting : NSTemporaryDirectory() + outputSetting
        let base = URL(fileURLWithPath: outputPath).deletingPathExtension().path
        let rounds = Int(environment["KEYBOARD_SWITCH_ROUNDS"] ?? "") ?? 4
        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        Thread.sleep(forTimeInterval: 1.5)

        for round in 0..<rounds {
            // The system's one-time tip on switching keyboards covers the keyboard until closed.
            let tipButton = app.buttons["Continue"]
            if tipButton.waitForExistence(timeout: 1) {
                tipButton.tap()
                Thread.sleep(forTimeInterval: 1)
            }
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(base)-\(round).png"))
            var lines: [String] = []
            func collect(_ snapshot: XCUIElementSnapshot) {
                let frame = snapshot.frame
                if snapshot.label.isEmpty == false {
                    lines.append("\(snapshot.elementType.rawValue)\t\(snapshot.label)\t\(frame.minX),\(frame.minY),\(frame.width),\(frame.height)")
                }
                snapshot.children.forEach(collect)
            }
            collect(try app.snapshot())
            try lines.joined(separator: "\n").write(toFile: "\(base)-\(round).tsv", atomically: true, encoding: .utf8)

            let nextKeyboard = app.descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", "Next keyboard"))
                .firstMatch
            guard nextKeyboard.waitForExistence(timeout: 2) else { return }
            nextKeyboard.tap()
            Thread.sleep(forTimeInterval: 1.5)
        }
    }
}
