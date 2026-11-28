import XCTest

/// Measurement only: records which emoji the system keyboard finds for words in each of its
/// languages, in the emoji keyboard's search and in the suggestion bar. Plays the steps in the JSON
/// array that `EMOJI_LANGUAGE_SCRIPT` names and writes a record per "search", "bar", and "keyboard"
/// step, as JSON, to `EMOJI_LANGUAGE_OUTPUT`, rewritten after each.
///
/// Steps: "next" taps the Next keyboard button; "pick:<name>" holds it and picks the keyboard so
/// named from its menu, and "checkpick:<name>" saves the menu's screenshot and elements first;
/// "keyboard:<name>" records which keyboard shows (its keys and the Next keyboard button);
/// "emoji" opens the emoji keyboard; "letters" goes back to the letters; "search:<word>" types the
/// word into the emoji keyboard's search field with its keys and records the results shown, left
/// to right, and "searchtext:<word>" types it with the test's own typing, for letters without a
/// key; "bar:<word>" clears the text, types the word key by key, and records the suggestion bar;
/// "tap:<label>" taps an element so labeled, and "tapat:<x>,<y>" the screen at that point; "hold:<label>:<seconds>" holds it; "wait:<seconds>"
/// waits; "shot:<name>" and "elements:<name>" save a screenshot and every labeled element on
/// screen next to the output. With `EMOJI_LANGUAGE_HOST=messages` the text is typed in Messages'
/// first sample conversation instead of the host app.
final class EmojiLanguageProbeTests: XCTestCase {
    private struct Record: Encodable {
        let step: String
        let word: String
        let typed: String
        let results: [String]
        let elements: [String]
    }

    func testPlayEmojiLanguageScript() throws {
        let environment = ProcessInfo.processInfo.environment
        let scriptPath = try XCTUnwrap(environment["EMOJI_LANGUAGE_SCRIPT"], "EMOJI_LANGUAGE_SCRIPT is not set")
        let steps = try JSONDecoder().decode([String].self, from: Data(contentsOf: URL(fileURLWithPath: scriptPath)))
        let outputPath = try XCTUnwrap(environment["EMOJI_LANGUAGE_OUTPUT"], "EMOJI_LANGUAGE_OUTPUT is not set")
        // With EMOJI_LANGUAGE_HOST=messages, in the first sample conversation's message field instead.
        let inMessages = environment["EMOJI_LANGUAGE_HOST"] == "messages"
        let app = inMessages ? XCUIApplication(bundleIdentifier: "com.apple.MobileSMS") : XCUIApplication()
        let input: XCUIElement
        if inMessages {
            app.terminate()
            app.launch()
            let conversation = app.cells.firstMatch
            XCTAssertTrue(conversation.waitForExistence(timeout: 10), "no conversation")
            conversation.tap()
            Thread.sleep(forTimeInterval: 1.5)
            input = app.descendants(matching: .any).matching(identifier: "messageBodyField").firstMatch
        } else {
            app.launch()
            input = app.textViews["input"]
        }
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        input.tap()
        Thread.sleep(forTimeInterval: 1)
        var lastBar = ""

        func element(_ label: String) -> XCUIElement {
            app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        func key(_ label: String) -> XCUIElement {
            app.keys.matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        func labeledElements() throws -> [String] {
            var lines: [String] = []
            func collect(_ snapshot: XCUIElementSnapshot) {
                if snapshot.label.isEmpty == false || [.searchField, .textField].contains(snapshot.elementType) {
                    let frame = snapshot.frame
                    lines.append("\(snapshot.elementType.rawValue)\t\(snapshot.label)\t\(snapshot.identifier)\t\(snapshot.value.map { String(describing: $0) } ?? "")\t\(frame.minX),\(frame.minY),\(frame.width),\(frame.height)")
                }
                snapshot.children.forEach(collect)
            }
            collect(try app.snapshot())
            return lines
        }
        /// Taps each character's key; a space is the space key.
        func typeKeys(_ text: String) {
            for character in text {
                let label = character == " " ? "space" : String(character)
                if character.isUppercase, key(label).exists == false {
                    // Shift, by its identifier, as its label is in the keyboard's language.
                    app.buttons.matching(identifier: "shift").firstMatch.tap()
                    _ = key(label).waitForExistence(timeout: 1)
                }
                // A field that capitalizes shows its letters' capitals at a sentence's start.
                let direct = key(label).exists ? key(label) : key(label.uppercased())
                if direct.exists, direct.isHittable {
                    direct.tap()
                    continue
                }
                XCTFail("no key for \(character)")
            }
        }

        var records: [Record] = []
        func save() throws {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
            try encoder.encode(records).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        }
        let base = URL(fileURLWithPath: outputPath).deletingPathExtension().path

        for step in steps {
            let parts = step.split(separator: ":", maxSplits: 1).map(String.init)
            let argument = parts.count > 1 ? parts[1] : ""
            switch parts[0] {
            case "next":
                app.buttons["Next keyboard"].tap()
                Thread.sleep(forTimeInterval: 0.8)
            case "pick", "checkpick":
                let globe = app.buttons["Next keyboard"]
                XCTAssertTrue(globe.waitForExistence(timeout: 3))
                globe.press(forDuration: 1.2)
                if parts[0] == "checkpick" {
                    // The menu as it opens, marking the keyboard in use, before picking.
                    Thread.sleep(forTimeInterval: 0.5)
                    let name = argument.replacingOccurrences(of: " ", with: "_")
                    try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(base)-menu-\(name).png"))
                    try (try labeledElements()).joined(separator: "\n").write(toFile: "\(base)-menu-\(name).tsv", atomically: true, encoding: .utf8)
                }
                let choice = element(argument)
                XCTAssertTrue(choice.waitForExistence(timeout: 3), "no keyboard \(argument) in the menu")
                choice.tap()
                Thread.sleep(forTimeInterval: 1)
            case "keyboard":
                // The keys of the keyboard's first rows and its space key tell the keyboards apart.
                // With the Next keyboard button, whose value names the keyboard after this one.
                let lines = try labeledElements().filter {
                    $0.hasPrefix("\(XCUIElement.ElementType.key.rawValue)\t") || $0.contains("Next keyboard")
                }
                records.append(Record(step: "keyboard", word: argument, typed: "", results: [], elements: lines))
                try save()
            case "emoji":
                // Its label is in the keyboard's language; its identifier is not.
                let emojiKey = app.buttons.matching(identifier: "emoji").firstMatch
                if emojiKey.waitForExistence(timeout: 2) {
                    emojiKey.tap()
                } else {
                    XCTFail("no Emoji key")
                }
                Thread.sleep(forTimeInterval: 1)
            case "letters":
                let back = ["ABC", "letters"].map(element).first { $0.exists }
                try XCTUnwrap(back, "no key back to the letters").tap()
                Thread.sleep(forTimeInterval: 1)
            case "search", "searchtext":
                // Empties the field with its clear button once it holds a word; before the first word,
                // taps the field, which shows no search field element: its magnifying glass marks it.
                let clearText = app.buttons["Clear text"]
                if clearText.exists {
                    clearText.tap()
                } else {
                    let glass = app.images.matching(identifier: "magnifyingglass").firstMatch
                    XCTAssertTrue(glass.waitForExistence(timeout: 2), "no search field")
                    glass.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(CGVector(dx: 120, dy: 0)).tap()
                }
                Thread.sleep(forTimeInterval: 0.8)
                // "searchtext:<word>" sends the word through the test's own typing instead of the keys.
                if parts[0] == "searchtext" { app.typeText(argument) } else { typeKeys(argument) }
                Thread.sleep(forTimeInterval: 1.5)
                let lines = try labeledElements()
                // The search field's text: the text field in the keyboard's half of the screen.
                let typed = Self.searchText(in: lines)
                records.append(Record(step: parts[0], word: argument, typed: typed, results: Self.searchResults(in: lines), elements: lines))
                try save()
            case "bar":
                if inMessages {
                    // Messages has no clear button: the delete key, a press per character typed last.
                    let delete = app.keys.matching(identifier: "delete").firstMatch
                    for _ in 0..<(lastBar.count + 2) where delete.exists { delete.tap() }
                } else {
                    app.buttons["clear"].tap()
                    input.tap()
                }
                lastBar = argument
                Thread.sleep(forTimeInterval: 0.5)
                let firstRowKey = app.keyboards.keys.matching(NSPredicate(format: "label IN %@", ["q", "Q", "a", "A", "w", "W"])).firstMatch
                XCTAssertTrue(firstRowKey.waitForExistence(timeout: 3), "no letter keys")
                let reader = SuggestionBarReader(app: app, firstRowKey: firstRowKey)
                typeKeys(argument)
                Thread.sleep(forTimeInterval: 1.2)
                let bar = reader.readSettled()
                let typed = input.value as? String ?? ""
                let lines = try labeledElements().filter {
                    let frame = $0.split(separator: "\t").last?.split(separator: ",").compactMap { Double($0) } ?? []
                    return frame.count == 4 && reader.contains(CGRect(x: frame[0], y: frame[1], width: frame[2], height: frame[3]))
                }
                records.append(Record(step: "bar", word: argument, typed: typed, results: bar, elements: lines))
                try save()
            case "tap":
                let target = element(argument)
                XCTAssertTrue(target.waitForExistence(timeout: 3), "no \(argument)")
                target.tap()
                Thread.sleep(forTimeInterval: 0.6)
            case "tapat":
                // A place on the screen, in points, for what has no accessibility element.
                let point = argument.split(separator: ",").compactMap { Double($0) }
                XCTAssertEqual(point.count, 2, "tapat needs x,y")
                app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: point[0], dy: point[1])).tap()
                Thread.sleep(forTimeInterval: 0.6)
            case "hold":
                let holdParts = argument.split(separator: ":").map(String.init)
                let target = element(holdParts[0])
                XCTAssertTrue(target.waitForExistence(timeout: 3), "no \(holdParts[0])")
                target.press(forDuration: Double(holdParts.count > 1 ? holdParts[1] : "1") ?? 1)
                Thread.sleep(forTimeInterval: 0.6)
            case "wait":
                Thread.sleep(forTimeInterval: Double(argument) ?? 1)
            case "shot":
                try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(base)-\(argument).png"))
            case "elements":
                try (try labeledElements()).joined(separator: "\n").write(toFile: "\(base)-\(argument).tsv", atomically: true, encoding: .utf8)
            default:
                XCTFail("unknown step \(step)")
            }
        }
        try save()
    }

    /// The search field's text: the value of the text field in the keyboard's half of the screen.
    private static func searchText(in lines: [String]) -> String {
        let textField = String(XCUIElement.ElementType.textField.rawValue)
        for line in lines {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 5, columns[0] == textField else { continue }
            let frame = columns[4].split(separator: ",").compactMap { Double($0) }
            if frame.count == 4, frame[1] > 400 { return columns[3] }
        }
        return ""
    }

    /// The emoji search's results: the cells holding a single emoji, left to right.
    private static func searchResults(in lines: [String]) -> [String] {
        let cell = String(XCUIElement.ElementType.cell.rawValue)
        var results: [(x: Double, y: Double, label: String)] = []
        for line in lines {
            let columns = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard columns.count >= 5, columns[0] == cell, columns[1].isEmpty == false,
                  columns[1].unicodeScalars.contains(where: { $0.properties.isEmojiPresentation || $0.properties.isEmoji && $0.value > 0xFF })
            else { continue }
            let frame = columns[4].split(separator: ",").compactMap { Double($0) }
            guard frame.count == 4 else { continue }
            results.append((frame[0], frame[1], columns[1]))
        }
        return results.sorted { ($0.y, $0.x) < ($1.y, $1.x) }.map(\.label)
    }
}
