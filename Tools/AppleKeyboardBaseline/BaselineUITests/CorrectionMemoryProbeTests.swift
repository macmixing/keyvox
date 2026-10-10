import XCTest

/// Measurement only: plays a script of actions on the system keyboard in the host app and
/// records the text and the suggestion bar where the script asks, to measure what the keyboard
/// remembers when the user undoes a correction or keeps a word it does not know.
///
/// `TEST_RUNNER_MEMORY_SCRIPT` is a JSON array of steps, each `{"do": action, ...}`:
/// - `launch`: starts the host app fresh and shows the system keyboard. Set
///   `TEST_RUNNER_BASELINE_AUTOCAPITALIZE=1` to capitalize sentences, as most apps do.
/// - `type` with `text`: taps the letters at their key centers.
/// - `space`, `delete`: taps that key.
/// - `tapBar` with `label`: taps the suggestion bar's entry with that label.
/// - `tapRevert` with `label`: taps the bubble under a corrected word that puts back the word
///   as typed, labeled with that word.
/// - `clear`: empties the text view.
/// - `wait` with `seconds`.
/// - `record` with `name`: records the text and the bar.
/// - `dump` with `name`: writes every element the app shows next to the output, for finding
///   an element's label.
///
/// `TEST_RUNNER_MEMORY_OUTPUT` receives `[{"name", "text", "bar"}]`, rewritten after every record.
final class CorrectionMemoryProbeTests: XCTestCase {
    private struct Step: Decodable {
        let `do`: String
        let text: String?
        let label: String?
        let seconds: Double?
        let name: String?
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

        func tap(at point: CGPoint) {
            origin.withOffset(CGVector(dx: point.x, dy: point.y)).tap()
        }
    }

    func testPlayScript() throws {
        let environment = ProcessInfo.processInfo.environment
        let scriptPath = try XCTUnwrap(environment["MEMORY_SCRIPT"], "MEMORY_SCRIPT is not set")
        let outputPath = try XCTUnwrap(environment["MEMORY_OUTPUT"], "MEMORY_OUTPUT is not set")
        let steps = try JSONDecoder().decode([Step].self, from: Data(contentsOf: URL(fileURLWithPath: scriptPath)))
        let capitalizes = environment["BASELINE_AUTOCAPITALIZE"] == "1"

        var session: Session?
        var records: [Record] = []
        for (index, step) in steps.enumerated() {
            let context = "step \(index): \(step.do)"
            if step.do == "launch" {
                session = try launch(capitalizes: capitalizes)
                continue
            }
            let current = try XCTUnwrap(session, "\(context) before launch")
            switch step.do {
            case "type":
                for letter in try XCTUnwrap(step.text, context) {
                    current.tap(at: try XCTUnwrap(current.keyMap.point(for: letter, offset: [0, 0]), context))
                }
            case "space":
                current.tap(at: current.keyMap.spaceCenter)
            case "delete":
                current.app.keyboards.keys["delete"].tap()
            case "tapBar":
                let label = try XCTUnwrap(step.label, context)
                let entry = try XCTUnwrap(
                    element(labeled: label, in: current.app) { current.bar.contains($0) },
                    "\(context): no bar entry \(label)"
                )
                current.tap(at: CGPoint(x: entry.midX, y: entry.midY))
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
                try JSONEncoder().encode(records).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            case "dump":
                let name = try XCTUnwrap(step.name, context)
                try current.app.debugDescription.write(toFile: "\(outputPath).\(name).txt", atomically: true, encoding: .utf8)
            default:
                XCTFail("\(context): unknown action")
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
    }

    private func launch(capitalizes: Bool) throws -> Session {
        let app = XCUIApplication()
        if capitalizes {
            app.launchEnvironment["AUTOCAPITALIZE"] = "1"
        }
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
        let keyboard = app.keyboards.element
        let firstRowKey = keyboard.keys.matching(NSPredicate(format: "label IN %@", ["q", "Q"])).firstMatch
        return Session(
            app: app,
            input: input,
            keyMap: try KeyboardKeyMap(systemKeyboard: keyboard),
            bar: SuggestionBarReader(app: app, firstRowKey: firstRowKey),
            origin: app.coordinate(withNormalizedOffset: .zero)
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
