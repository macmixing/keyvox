import XCTest

/// Measurement only: plays a script of actions on the system keyboard in the host app and
/// records the text and the suggestion bar where the script asks, to measure what the keyboard
/// remembers when the user undoes a correction or keeps a word it does not know.
///
/// `TEST_RUNNER_MEMORY_SCRIPT` names a file holding a JSON array of steps, or
/// `TEST_RUNNER_MEMORY_SCRIPT_JSON` holds the array itself, as on a device, which cannot read the
/// Mac's files. Each step is `{"do": action, ...}`:
/// - `launch`: starts the host app fresh and shows the system keyboard, or the third-party
///   keyboard that has a key labeled `TEST_RUNNER_BASELINE_KEYBOARD_MARKER` when that is set. Set
///   `TEST_RUNNER_BASELINE_AUTOCAPITALIZE=1` to capitalize sentences, as most apps do, and
///   `TEST_RUNNER_BASELINE_SMART_QUOTES=1` to turn the text view's smart quotes on.
/// - `type` with `text`: taps the letters at their key centers.
/// - `tapLetter` with `text`, `dx`, and `dy`: taps that letter's key that many key widths and
///   heights from its center, as a slip toward a neighboring key lands.
/// - `space`, `delete`, `shift`: taps that key; `shift` before a letter types it as a capital.
/// - `holdDelete` with `seconds`: holds the delete key down that long.
/// - `page` with `name`: shows the keyboard's `letters`, `numbers`, or `symbols` page.
/// - `tapKey` with `label`: taps the key with that label on the page showing.
/// - `holdKey` with `label`, `dx`, and `dy`: holds that key until its popup opens, then slides
///   that many points from the key's center and lifts there.
/// - `tapBar` with `label`: taps the suggestion bar's entry with that label.
/// - `holdBar` with `label`: presses and holds that entry for a second.
/// - `tapBarAt` with `index`: taps the suggestion bar's entry at that place, counted from the
///   left, whatever it reads.
/// - `tapRevert` with `label`: taps the bubble under a corrected word that puts back the word
///   as typed, labeled with that word.
/// - `clear`: empties the text view.
/// - `wait` with `seconds`.
/// - `record` with `name`: records the text and the bar.
/// - `dump` with `name`: writes every element the app shows next to the output, for finding
///   an element's label.
///
/// `TEST_RUNNER_MEMORY_OUTPUT`, when set, receives `[{"name", "text", "bar"}]`, rewritten after
/// every record.
final class CorrectionMemoryProbeTests: XCTestCase {
    private struct Step: Decodable {
        let `do`: String
        let text: String?
        let label: String?
        let seconds: Double?
        let name: String?
        let index: Int?
        let dx: Double?
        let dy: Double?
    }

    private struct Record: Encodable {
        let name: String
        let text: String
        let bar: [String]
    }

    /// The host app with its text view focused and the system keyboard showing.
    private struct Session {
        let app: XCUIApplication
        let input: XCUIElement
        let keyMap: KeyboardKeyMap
        let bar: SuggestionBarReader
        let origin: XCUICoordinate
        /// Finds a key on the page showing, and moves the keyboard to a page.
        let key: (String) -> XCUIElement
        let openPage: (String) throws -> Void

        func tap(at point: CGPoint) {
            origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        }
    }

    func testPlayScript() throws {
        let environment = ProcessInfo.processInfo.environment
        let script: Data
        if let inline = environment["MEMORY_SCRIPT_JSON"] {
            script = Data(inline.utf8)
        } else {
            let scriptPath = try XCTUnwrap(environment["MEMORY_SCRIPT"], "MEMORY_SCRIPT or MEMORY_SCRIPT_JSON is not set")
            script = try Data(contentsOf: URL(fileURLWithPath: scriptPath))
        }
        let outputPath = environment["MEMORY_OUTPUT"]
        let steps = try JSONDecoder().decode([Step].self, from: script)
        let capitalizes = environment["BASELINE_AUTOCAPITALIZE"] == "1"
        let customKeyboardMarker = environment["BASELINE_KEYBOARD_MARKER"]

        var session: Session?
        var records: [Record] = []
        for (index, step) in steps.enumerated() {
            let context = "step \(index): \(step.do)"
            if step.do == "launch" {
                session = try launch(capitalizes: capitalizes, customKeyboardMarker: customKeyboardMarker)
                continue
            }
            let current = try XCTUnwrap(session, "\(context) before launch")
            switch step.do {
            case "type":
                for letter in try XCTUnwrap(step.text, context) {
                    current.tap(at: try XCTUnwrap(current.keyMap.point(for: letter, offset: [0, 0]), context))
                }
            case "tapLetter":
                let letter = try XCTUnwrap(step.text?.first, context)
                current.tap(at: try XCTUnwrap(current.keyMap.point(for: letter, offset: [step.dx ?? 0, step.dy ?? 0]), context))
            case "space":
                current.tap(at: current.keyMap.spaceCenter)
            case "delete", "shift":
                // The system keyboard labels its keys in lowercase, KeyVox's capitalized.
                current.app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label IN %@", [step.do, step.do.capitalized]))
                    .firstMatch
                    .tap()
            case "holdDelete":
                current.app.descendants(matching: .any)
                    .matching(NSPredicate(format: "label IN %@", ["delete", "Delete"]))
                    .firstMatch
                    .press(forDuration: try XCTUnwrap(step.seconds, context))
            case "page":
                try current.openPage(try XCTUnwrap(step.name, context))
            case "tapKey":
                let label = try XCTUnwrap(step.label, context)
                let key = current.key(label)
                try XCTUnwrap(key.exists ? key : nil, "\(context): no key \(label)").tap()
            case "holdKey":
                let label = try XCTUnwrap(step.label, context)
                let key = current.key(label)
                let center = try XCTUnwrap(key.exists ? key : nil, "\(context): no key \(label)")
                    .coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                center.press(
                    forDuration: 1,
                    thenDragTo: center.withOffset(CGVector(dx: step.dx ?? 0, dy: step.dy ?? 0)),
                    withVelocity: .slow,
                    thenHoldForDuration: 0.4
                )
            case "tapBar", "holdBar":
                let label = try XCTUnwrap(step.label, context)
                let entry = try XCTUnwrap(
                    element(labeled: label, in: current.app) { current.bar.contains($0) },
                    "\(context): no bar entry \(label)"
                )
                let point = current.origin.withOffset(CGVector(dx: entry.midX, dy: entry.midY))
                if step.do == "holdBar" {
                    point.press(forDuration: 1)
                } else {
                    point.tap()
                }
            case "tapBarAt":
                let index = try XCTUnwrap(step.index, context)
                let entries = current.bar.readSettled()
                let label = try XCTUnwrap(entries.indices.contains(index) ? entries[index] : nil, "\(context): bar is \(entries)")
                let entry = try XCTUnwrap(
                    element(labeled: label, in: current.app) { current.bar.contains($0) },
                    "\(context): no bar entry \(label)"
                )
                current.origin.withOffset(CGVector(dx: entry.midX, dy: entry.midY)).tap()
            case "tapRevert":
                let label = try XCTUnwrap(step.label, context)
                let bubble = try XCTUnwrap(
                    element(labeled: label, in: current.app) { $0.midY < current.bar.barTop },
                    "\(context): no bubble \(label)"
                )
                current.tap(at: CGPoint(x: bubble.midX, y: bubble.midY))
            case "clear":
                current.app.buttons["clear"].tap()
                current.input.tap()
            case "wait":
                Thread.sleep(forTimeInterval: try XCTUnwrap(step.seconds, context))
            case "record":
                Thread.sleep(forTimeInterval: 0.8)
                records.append(Record(
                    name: try XCTUnwrap(step.name, context),
                    text: current.input.value as? String ?? "",
                    bar: current.bar.readSettled()
                ))
                if let outputPath {
                    try JSONEncoder().encode(records).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
                }
            case "dump":
                let name = try XCTUnwrap(step.name, context)
                let outputPath = try XCTUnwrap(outputPath, "\(context): MEMORY_OUTPUT is not set")
                try current.app.debugDescription.write(toFile: "\(outputPath).\(name).txt", atomically: true, encoding: .utf8)
            default:
                XCTFail("\(context): unknown action")
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
    }

    private func launch(capitalizes: Bool, customKeyboardMarker: String?) throws -> Session {
        let app = XCUIApplication()
        if capitalizes {
            app.launchEnvironment["AUTOCAPITALIZE"] = "1"
        }
        if ProcessInfo.processInfo.environment["BASELINE_SMART_QUOTES"] == "1" {
            app.launchEnvironment["SMART_QUOTES"] = "1"
        }
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        let firstRowLetters = NSPredicate(format: "label IN %@", ["q", "Q"])
        let keyMap: KeyboardKeyMap
        let firstRowKey: XCUIElement
        let key: (String) -> XCUIElement
        let openPage: (String) throws -> Void
        if let customKeyboardMarker {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: customKeyboardMarker, in: app))
            keyMap = try KeyboardKeyMap(customKeyboardIn: app)
            firstRowKey = app.descendants(matching: .any).matching(firstRowLetters).firstMatch
            key = { KeyVoxKeyboardPages.key($0, in: app) }
            openPage = { try KeyVoxKeyboardPages.open($0, in: app) }
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
            let keyboard = app.keyboards.element
            keyMap = try KeyboardKeyMap(systemKeyboard: keyboard)
            firstRowKey = keyboard.keys.matching(firstRowLetters).firstMatch
            key = { keyboard.keys[$0].firstMatch }
            openPage = { try SystemKeyboardPages.open($0, on: keyboard) }
        }
        return Session(
            app: app,
            input: input,
            keyMap: keyMap,
            bar: SuggestionBarReader(app: app, firstRowKey: firstRowKey),
            origin: app.coordinate(withNormalizedOffset: .zero),
            key: key,
            openPage: openPage
        )
    }

    /// The frame of the first element labeled `label` whose frame passes `isWanted`.
    private func element(labeled label: String, in app: XCUIApplication, where isWanted: (CGRect) -> Bool) -> CGRect? {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .allElementsBoundByIndex
            .map(\.frame)
            .first(where: isWanted)
    }
}
