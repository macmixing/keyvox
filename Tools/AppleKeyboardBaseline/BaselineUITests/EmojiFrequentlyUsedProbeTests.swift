import XCTest

/// Records how the system emoji keyboard's Frequently Used section changes as emoji are typed, by
/// watching it: plays the steps in the JSON array `EMOJI_FREQUENT_SCRIPT` and writes what the
/// section shows at each "record" step, as JSON, to `EMOJI_FREQUENT_OUTPUT`. Steps:
/// "category:<name>" taps a category in the bar, "tap:<emoji>" types an emoji shown on screen,
/// "reopen" goes to the letters and back to the emoji keyboard, and "record:<name>" scrolls to
/// the section and records its emoji, column by column, and "shot:<name>" saves a screenshot next
/// to the output; "wait:<seconds>" waits; "swipe" scrolls the grid about 200 points onward;
/// "drag:<x1>:<y1>:<x2>:<y2>:<slide seconds>:<rest seconds>" slides a finger between two points;
/// "seek:<emoji>[:<y>]" swipes onward until that emoji shows, with "swipe:<y>" dragging at the
/// section titles' height on a keyboard whose titles sit elsewhere;
/// "press:<emoji>:<seconds>" holds a finger on an emoji shown on screen;
/// "slide:<emoji>:<seconds>:<x>:<y>" holds it that long, then slides to that screen point and lifts;
/// "slideby:<emoji>:<seconds>:<dx>:<dy>:<rest>" holds it, slides that far from its center, and rests
/// there before lifting; "button:<label>" taps an element so labeled when one shows; "type:<text>"
/// taps the keys for each character; "elements:<name>" saves every element on screen, with its
/// frame, next to the output.
final class EmojiFrequentlyUsedProbeTests: XCTestCase {
    private struct Record: Encodable {
        let name: String
        let frequentlyUsed: [String]
        let text: String
    }

    func testRecordFrequentlyUsed() throws {
        let environment = ProcessInfo.processInfo.environment
        let steps = try JSONDecoder().decode([String].self, from: Data(try XCTUnwrap(environment["EMOJI_FREQUENT_SCRIPT"]).utf8))
        let outputSetting = try XCTUnwrap(environment["EMOJI_FREQUENT_OUTPUT"], "EMOJI_FREQUENT_OUTPUT is not set")
        // On a phone, a name without a folder lands in the runner's temporary folder, to copy back.
        let outputPath = outputSetting.hasPrefix("/") ? outputSetting : NSTemporaryDirectory() + outputSetting
        let app = XCUIApplication()
        app.launch()
        let input = app.textViews["input"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        // With EMOJI_FREQUENT_KEYBOARD_MARKER, a key only it has, the keyboard with that key.
        if let marker = environment["EMOJI_FREQUENT_KEYBOARD_MARKER"] {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: marker, in: app))
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: app))
        }

        func swipe(atY y: Double = 553) {
            // In the band of section titles, so the drag scrolls rather than presses an emoji; on the
            // system keyboard of a 402-point-wide iPhone that band sits at 553 points.
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 340, dy: y))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -200, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.8)
            Thread.sleep(forTimeInterval: 0.5)
        }
        func element(_ label: String) -> XCUIElement {
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        func tap(_ label: String) {
            let target = element(label)
            XCTAssertTrue(target.waitForExistence(timeout: 3), "no \(label)")
            target.tap()
            Thread.sleep(forTimeInterval: 0.6)
        }
        // A home-button iPhone with other keyboards shows its globe in the emoji key's place.
        tap(element("Emoji").waitForExistence(timeout: 2) ? "Emoji" : "Next keyboard")

        var records: [Record] = []
        for step in steps {
            let (action, _, argument) = step.partition(":")
            switch action {
            case "category":
                tap("\(argument) category")
            case "tap":
                let key = app.keys.matching(NSPredicate(format: "label == %@", argument)).firstMatch
                if key.waitForExistence(timeout: 3) == false {
                    print("EMOJI-FREQUENT missing \(argument); keys shown: \(app.keys.allElementsBoundByIndex.prefix(40).map(\.label))")
                }
                key.tap()
                Thread.sleep(forTimeInterval: 0.6)
            case "point":
                // A key the snapshot leaves unlabeled, by where it shows: point:<x>:<y>.
                let parts = argument.split(separator: ":").compactMap { Double($0) }
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: parts[0], dy: parts[1])).tap()
                Thread.sleep(forTimeInterval: 0.6)
            case "shot":
                let path = URL(fileURLWithPath: outputPath).deletingPathExtension().path + "-\(argument).png"
                try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: path))
            case "press":
                let parts = argument.split(separator: ":", maxSplits: 1).map(String.init)
                let key = app.keys.matching(NSPredicate(format: "label == %@", parts[0])).firstMatch
                XCTAssertTrue(key.waitForExistence(timeout: 3), "no \(parts[0])")
                print("EMOJI-FREQUENT press \(parts[0]) from \(key.frame) at \(Date().timeIntervalSince1970)")
                key.press(forDuration: Double(parts.count > 1 ? parts[1] : "1") ?? 1)
                print("EMOJI-FREQUENT released \(parts[0]) at \(Date().timeIntervalSince1970)")
                Thread.sleep(forTimeInterval: 0.6)
            case "slide":
                let parts = argument.split(separator: ":").map(String.init)
                let key = app.keys.matching(NSPredicate(format: "label == %@", parts[0])).firstMatch
                XCTAssertTrue(key.waitForExistence(timeout: 3), "no \(parts[0])")
                let target = app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: Double(parts[2]) ?? 0, dy: Double(parts[3]) ?? 0))
                key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                    .press(forDuration: Double(parts[1]) ?? 1, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.3)
                Thread.sleep(forTimeInterval: 0.6)
            case "slideby":
                let parts = argument.split(separator: ":").map(String.init)
                // An emoji on the page is a key; a search result is a cell.
                let key = app.descendants(matching: .any).matching(NSPredicate(
                    format: "label == %@ AND elementType IN %@",
                    parts[0],
                    [XCUIElement.ElementType.key.rawValue, XCUIElement.ElementType.cell.rawValue]
                )).firstMatch
                XCTAssertTrue(key.waitForExistence(timeout: 3), "no \(parts[0])")
                let center = key.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                print("EMOJI-FREQUENT slide \(parts[0]) from \(key.frame) at \(Date().timeIntervalSince1970)")
                center.press(
                    forDuration: Double(parts[1]) ?? 1,
                    thenDragTo: center.withOffset(CGVector(dx: Double(parts[2]) ?? 0, dy: Double(parts[3]) ?? 0)),
                    withVelocity: .slow,
                    thenHoldForDuration: Double(parts[4]) ?? 0.3
                )
                print("EMOJI-FREQUENT lifted \(parts[0]) at \(Date().timeIntervalSince1970)")
                Thread.sleep(forTimeInterval: 0.6)
            case "type":
                for character in argument {
                    let label = character == " " ? "space" : String(character)
                    // The system keyboard's keys are keys; another keyboard's may only carry the label.
                    let systemKey = app.keys.matching(NSPredicate(format: "label == %@", label)).firstMatch
                    let key = systemKey.exists ? systemKey : element(label)
                    XCTAssertTrue(key.waitForExistence(timeout: 3), "no key \(character)")
                    key.tap()
                }
                Thread.sleep(forTimeInterval: 0.8)
            case "elements":
                var lines: [String] = []
                func collect(_ snapshot: XCUIElementSnapshot) {
                    let frame = snapshot.frame
                    if snapshot.label.isEmpty == false || snapshot.elementType == .searchField || snapshot.elementType == .textField
                        || snapshot.elementType == .textView {
                        lines.append("\(snapshot.elementType.rawValue)\t\(snapshot.label)\t\(snapshot.value.map { String(describing: $0) } ?? "")\t\(frame.minX),\(frame.minY),\(frame.width),\(frame.height)")
                    }
                    snapshot.children.forEach(collect)
                }
                collect(try app.snapshot())
                let path = URL(fileURLWithPath: outputPath).deletingPathExtension().path + "-\(argument).tsv"
                try lines.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
            case "button":
                // Taps it only when it shows, as a one-time tip's button does.
                let button = element(argument)
                if button.waitForExistence(timeout: 2) {
                    button.tap()
                    Thread.sleep(forTimeInterval: 0.6)
                }
            case "swipeat":
                // As swipe, at another keyboard's height: swipeat:<y>.
                let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 340, dy: Double(argument) ?? 553))
                start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -200, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.8)
                Thread.sleep(forTimeInterval: 0.5)
            case "swipe":
                swipe(atY: Double(argument) ?? 553)
            case "drag":
                // Touches down at one screen point, slides to another, and rests there before
                // lifting: drag:<x1>:<y1>:<x2>:<y2>:<seconds to slide>:<seconds resting>.
                let parts = argument.split(separator: ":").compactMap { Double($0) }
                let origin = app.coordinate(withNormalizedOffset: .zero)
                let start = origin.withOffset(CGVector(dx: parts[0], dy: parts[1]))
                let end = origin.withOffset(CGVector(dx: parts[2], dy: parts[3]))
                let velocity = XCUIGestureVelocity(abs(parts[2] - parts[0]) / max(parts[4], 0.01))
                print("EMOJI-FREQUENT drag at \(Date().timeIntervalSince1970)")
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: velocity, thenHoldForDuration: parts[5])
                print("EMOJI-FREQUENT lifted at \(Date().timeIntervalSince1970)")
                Thread.sleep(forTimeInterval: 0.6)
            case "panel":
                // Taps the two-person skin-tone panel of a held emoji: panel:<emoji>:<dx>:<dy>, from
                // the panel's top center, which sits centered over the emoji, kept 6 points inside
                // the screen, with its bottom 18 points above the emoji (measured in screenshots).
                let parts = argument.split(separator: ":").map(String.init)
                let key = app.keys.matching(NSPredicate(format: "label == %@", parts[0])).firstMatch
                XCTAssertTrue(key.waitForExistence(timeout: 3), "no \(parts[0])")
                let (width, height): (Double, Double) = (247.2, 199.2)
                let screenWidth = app.frame.width
                let centerX = min(max(key.frame.midX, 6 + width / 2), screenWidth - 6 - width / 2)
                let top = key.frame.minY - 18 - height
                app.coordinate(withNormalizedOffset: .zero)
                    .withOffset(CGVector(dx: centerX + (Double(parts[1]) ?? 0), dy: top + (Double(parts[2]) ?? 0)))
                    .tap()
                Thread.sleep(forTimeInterval: 0.6)
            case "seek":
                // Scrolls the grid onward until the emoji shows, at most 150 swipes:
                // seek:<emoji>[:<y of the section titles>].
                let parts = argument.split(separator: ":").map(String.init)
                let key = app.keys.matching(NSPredicate(format: "label == %@", parts[0])).firstMatch
                for _ in 0..<150 where (key.exists && key.isHittable) == false {
                    swipe(atY: parts.count > 1 ? Double(parts[1]) ?? 553 : 553)
                }
                XCTAssertTrue(key.exists && key.isHittable, "no \(parts[0])")
            case "hold":
                // Holds any element by its label, a button as well as a key: hold:<label>:<seconds>.
                let parts = argument.split(separator: ":").map(String.init)
                let target = element(parts[0])
                XCTAssertTrue(target.waitForExistence(timeout: 3), "no \(parts[0])")
                print("EMOJI-FREQUENT hold \(parts[0]) at \(Date().timeIntervalSince1970)")
                target.press(forDuration: Double(parts.count > 1 ? parts[1] : "1") ?? 1)
                print("EMOJI-FREQUENT released \(parts[0]) at \(Date().timeIntervalSince1970)")
                Thread.sleep(forTimeInterval: 0.6)
            case "home":
                // Leaves the app and comes back, so the keyboard goes away and shows again.
                XCUIDevice.shared.press(.home)
                Thread.sleep(forTimeInterval: 2)
                app.activate()
                Thread.sleep(forTimeInterval: 2)
            case "wait":
                Thread.sleep(forTimeInterval: Double(argument) ?? 0)
            case "reopen":
                tap(element("letters").exists ? "letters" : "ABC")
                tap("Emoji")
            case "record":
                tap("Frequently Used category")
                records.append(Record(name: argument, frequentlyUsed: try Self.frequentlyUsed(in: app), text: input.value as? String ?? ""))
                try JSONEncoder().encode(records).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
            default:
                XCTFail("unknown step \(step)")
            }
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        try encoder.encode(records).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
    }

    /// The emoji left of the section after Frequently Used, column by column.
    private static func frequentlyUsed(in app: XCUIApplication) throws -> [String] {
        var cells: [(x: CGFloat, y: CGFloat, label: String)] = []
        var nextTitleX = CGFloat.infinity
        func collect(_ snapshot: XCUIElementSnapshot) {
            let frame = snapshot.frame
            if snapshot.elementType == .key, snapshot.identifier == snapshot.label, snapshot.label.isEmpty == false,
               frame.width < 40, frame.height < 40, frame.height > 20 {
                cells.append((frame.minX, frame.minY, snapshot.label))
            } else if snapshot.elementType == .other, snapshot.label != "FREQUENTLY USED",
                      snapshot.label == snapshot.label.uppercased(), snapshot.label.contains(where: \.isLetter),
                      frame.height == 30 {
                nextTitleX = min(nextTitleX, frame.minX)
            }
            snapshot.children.forEach(collect)
        }
        collect(try app.snapshot())
        // A section's title starts 2 points after its first column (EmojiKeyboardProbeTests).
        return cells.filter { $0.x < nextTitleX - 2 }.sorted { ($0.x, $0.y) < ($1.x, $1.y) }.map(\.label)
    }
}

private extension String {
    func partition(_ separator: Character) -> (String, Bool, String) {
        guard let index = firstIndex(of: separator) else { return (self, false, "") }
        return (String(self[..<index]), true, String(self[self.index(after: index)...]))
    }
}
