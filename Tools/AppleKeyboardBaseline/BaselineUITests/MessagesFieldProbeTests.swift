import XCTest

/// Records how tall Messages' message field is as a keyboard types and deletes, by watching it:
/// opens the first conversation, focuses its message field, switches to the keyboard with the key
/// `MESSAGES_FIELD_KEYBOARD_MARKER` (the system keyboard unless set), and plays the steps in the
/// JSON array `MESSAGES_FIELD_SCRIPT`, saving the field's frame and text after each step to
/// `MESSAGES_FIELD_OUTPUT`, with a screenshot next to it. Steps: "tap:<label>" taps an element so
/// labeled; "field" taps the message field; "wait:<seconds>" waits; "elements:<name>" saves every
/// labeled element on screen, with its type and frame, next to the output.
final class MessagesFieldProbeTests: XCTestCase {
    private struct Record: Encodable {
        let step: String
        let fieldFrame: String
        let text: String
    }

    func testRecordMessageFieldHeight() throws {
        let environment = ProcessInfo.processInfo.environment
        let steps = try JSONDecoder().decode([String].self, from: Data(try XCTUnwrap(environment["MESSAGES_FIELD_SCRIPT"]).utf8))
        let outputPath = try XCTUnwrap(environment["MESSAGES_FIELD_OUTPUT"], "MESSAGES_FIELD_OUTPUT is not set")
        let base = URL(fileURLWithPath: outputPath).deletingPathExtension().path
        let messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        messages.terminate()
        messages.launch()

        func element(_ label: String) -> XCUIElement {
            messages.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
        }
        func saveElements(_ name: String) throws {
            var lines: [String] = []
            func collect(_ snapshot: XCUIElementSnapshot) {
                if snapshot.label.isEmpty == false || snapshot.elementType == .textView || snapshot.elementType == .textField {
                    let frame = snapshot.frame
                    lines.append("\(snapshot.elementType.rawValue)\t\(snapshot.identifier)\t\(snapshot.label)\t\(frame.minX),\(frame.minY),\(frame.width),\(frame.height)")
                }
                snapshot.children.forEach(collect)
            }
            collect(try messages.snapshot())
            try lines.joined(separator: "\n").write(toFile: "\(base)-\(name).tsv", atomically: true, encoding: .utf8)
        }

        // The simulator's Messages lists sample conversations and offers no new message.
        let conversation = messages.cells.firstMatch
        if conversation.waitForExistence(timeout: 10) == false {
            try saveElements("launch")
            XCTFail("no conversation")
            return
        }
        conversation.tap()
        Thread.sleep(forTimeInterval: 1.5)
        let field = messages.descendants(matching: .any).matching(identifier: "messageBodyField").firstMatch
        if field.waitForExistence(timeout: 5) == false {
            try saveElements("conversation")
            XCTFail("no message field")
            return
        }
        field.tap()
        Thread.sleep(forTimeInterval: 1)
        if let marker = environment["MESSAGES_FIELD_KEYBOARD_MARKER"] {
            XCTAssertTrue(KeyboardSwitcher.switchToKeyboard(withKey: marker, in: messages))
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: messages))
        }

        var records: [Record] = []
        func record(_ step: String) throws {
            let frame = field.frame
            records.append(Record(
                step: step,
                fieldFrame: "\(frame.minX),\(frame.minY),\(frame.width),\(frame.height)",
                text: field.value as? String ?? ""
            ))
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: "\(base)-\(records.count - 1).png"))
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            try encoder.encode(records).write(to: URL(fileURLWithPath: outputPath), options: .atomic)
        }
        try record("start")
        for step in steps {
            let (action, argument) = step.firstIndex(of: ":").map { (String(step[..<$0]), String(step[step.index(after: $0)...])) } ?? (step, "")
            switch action {
            case "tap":
                let target = element(argument)
                XCTAssertTrue(target.waitForExistence(timeout: 3), "no \(argument)")
                target.tap()
                Thread.sleep(forTimeInterval: 1)
            case "field":
                field.tap()
                Thread.sleep(forTimeInterval: 1)
            case "wait":
                Thread.sleep(forTimeInterval: Double(argument) ?? 0)
            case "elements":
                try saveElements(argument)
            default:
                XCTFail("unknown step \(step)")
            }
            try record(step)
        }
    }
}
