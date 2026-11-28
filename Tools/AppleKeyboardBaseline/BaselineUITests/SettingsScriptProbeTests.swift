import XCTest

/// Measurement only: plays the steps in the JSON array `SETTINGS_SCRIPT` in the Settings app, to set
/// up a simulator the way a measurement needs, such as adding the system's language keyboards.
/// Steps: "tap:<label>" taps the element so labeled, scrolling down until it shows;
/// "tapid:<identifier>" taps the element with that identifier; "tapbegins:<prefix>" taps the first element whose label starts so; "back" taps the navigation
/// bar's back button; "drag:<label>:<label>" drags the first element onto the second; "swipeup" scrolls down a page; "wait:<seconds>" waits; "elements:<name>" saves every labeled element on
/// screen, with its frame, and "shot:<name>" a screenshot, both into `SETTINGS_SCRIPT_OUTPUT_DIR`.
final class SettingsScriptProbeTests: XCTestCase {
    func testPlaySettingsScript() throws {
        let environment = ProcessInfo.processInfo.environment
        let steps = try JSONDecoder().decode([String].self, from: Data(try XCTUnwrap(environment["SETTINGS_SCRIPT"]).utf8))
        let outputDirectory = try XCTUnwrap(environment["SETTINGS_SCRIPT_OUTPUT_DIR"], "SETTINGS_SCRIPT_OUTPUT_DIR is not set")
        try FileManager.default.createDirectory(atPath: outputDirectory, withIntermediateDirectories: true)
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate()
        settings.launch()

        func tap(_ predicate: NSPredicate, named name: String) {
            let target = settings.descendants(matching: .any).matching(predicate).firstMatch
            var swipes = 0
            while (target.exists == false || target.isHittable == false), swipes < 40 {
                if target.waitForExistence(timeout: 1), target.isHittable { break }
                settings.swipeUp(velocity: .slow)
                swipes += 1
            }
            XCTAssertTrue(target.exists && target.isHittable, "\(name) not found")
            target.tap()
            Thread.sleep(forTimeInterval: 1)
        }

        for step in steps {
            let parts = step.split(separator: ":", maxSplits: 1).map(String.init)
            let argument = parts.count > 1 ? parts[1] : ""
            switch parts[0] {
            case "tap":
                tap(NSPredicate(format: "label == %@", argument), named: argument)
            case "tapid":
                tap(NSPredicate(format: "identifier == %@", argument), named: argument)
            case "tapbegins":
                tap(NSPredicate(format: "label BEGINSWITH %@", argument), named: argument)
            case "back":
                settings.navigationBars.buttons.element(boundBy: 0).tap()
                Thread.sleep(forTimeInterval: 1)
            case "drag":
                // Drags one element onto another, as a list's reorder handle: drag:<label>:<label>.
                let labels = argument.split(separator: ":", maxSplits: 1).map(String.init)
                let from = settings.descendants(matching: .any).matching(NSPredicate(format: "label == %@", labels[0])).firstMatch
                let to = settings.descendants(matching: .any).matching(NSPredicate(format: "label == %@", labels[1])).firstMatch
                XCTAssertTrue(from.waitForExistence(timeout: 3) && to.exists, "no \(argument)")
                from.press(forDuration: 0.8, thenDragTo: to, withVelocity: .slow, thenHoldForDuration: 0.5)
                Thread.sleep(forTimeInterval: 1.5)
            case "swipeup":
                settings.swipeUp(velocity: .slow)
                Thread.sleep(forTimeInterval: 1)
            case "wait":
                Thread.sleep(forTimeInterval: Double(argument) ?? 1)
            case "shot":
                try XCUIScreen.main.screenshot().pngRepresentation
                    .write(to: URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(argument).png"))
            case "elements":
                var lines: [String] = []
                func collect(_ snapshot: XCUIElementSnapshot) {
                    if snapshot.label.isEmpty == false {
                        let frame = snapshot.frame
                        lines.append("\(snapshot.elementType.rawValue)\t\(snapshot.label)\t\(snapshot.identifier)\t\(snapshot.value.map { String(describing: $0) } ?? "")\t\(frame.minX),\(frame.minY),\(frame.width),\(frame.height)")
                    }
                    snapshot.children.forEach(collect)
                }
                collect(try settings.snapshot())
                try lines.joined(separator: "\n")
                    .write(toFile: URL(fileURLWithPath: outputDirectory).appendingPathComponent("\(argument).tsv").path, atomically: true, encoding: .utf8)
            default:
                XCTFail("unknown step \(step)")
            }
        }
    }
}
