import OSLog
import XCTest

/// Sends messages in Messages' most recent conversation with one keyboard, so a trace of the
/// device shows how the sent bubble animates over it. The keyboard is the one with the key
/// `MESSAGES_SEND_KEYBOARD_MARKER`, or the system keyboard when it is not set; it sends
/// `MESSAGES_SEND_COUNT` messages (default 3) inside a Points of Interest interval named for it.
final class MessagesSendProbeTests: XCTestCase {
    private let signposter = OSSignposter(subsystem: "org.keyvox.baseline", category: .pointsOfInterest)

    func testSendWithKeyboard() throws {
        let environment = ProcessInfo.processInfo.environment
        let marker = environment["MESSAGES_SEND_KEYBOARD_MARKER"]
        let count = Int(environment["MESSAGES_SEND_COUNT"] ?? "") ?? 3

        let messages = XCUIApplication(bundleIdentifier: "com.apple.MobileSMS")
        messages.activate()
        let field = messages.descendants(matching: .any).matching(identifier: "messageBodyField").firstMatch
        if field.waitForExistence(timeout: 3) == false {
            let conversation = messages.cells.firstMatch
            XCTAssertTrue(conversation.waitForExistence(timeout: 10), "no conversation")
            conversation.tap()
            XCTAssertTrue(field.waitForExistence(timeout: 5), "no message field")
        }
        field.tap()
        Thread.sleep(forTimeInterval: 1)

        if let marker {
            guard KeyboardSwitcher.switchToKeyboard(withKey: marker, in: messages) else {
                let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
                screenshot.lifetime = .keepAlways
                add(screenshot)
                let labels = XCTAttachment(string: messages.keyboards.descendants(matching: .any).allElementsBoundByIndex.map(\.label).joined(separator: "\n"))
                labels.lifetime = .keepAlways
                add(labels)
                XCTFail("no keyboard with \(marker)")
                return
            }
            try send(count, named: "KeyVoxSends", in: messages)
        } else {
            XCTAssertTrue(KeyboardSwitcher.switchToSystemKeyboard(in: messages), "no system keyboard")
            try send(count, named: "SystemKeyboardSends", in: messages)
        }
    }

    private func send(_ count: Int, named name: StaticString, in messages: XCUIApplication) throws {
        let interval = signposter.beginInterval(name)
        defer { signposter.endInterval(name, interval) }
        for _ in 0..<count {
            for letter in ["h", "i"] {
                let key = messages.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] %@", letter)).firstMatch
                XCTAssertTrue(key.waitForExistence(timeout: 3), "no \(letter) key")
                key.tap()
                Thread.sleep(forTimeInterval: 0.3)
            }
            let sendButton = messages.buttons.matching(NSPredicate(format: "identifier == 'sendButton' OR label == 'Send'")).firstMatch
            XCTAssertTrue(sendButton.waitForExistence(timeout: 3), "no send button")
            Thread.sleep(forTimeInterval: 1)
            sendButton.tap()
            Thread.sleep(forTimeInterval: 2)
        }
    }
}
