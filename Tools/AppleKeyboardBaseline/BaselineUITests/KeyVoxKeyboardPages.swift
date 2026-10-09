import XCTest

/// Finds KeyVox's keys by their accessibility labels, moves it between its letter page,
/// number page, and symbol page, and names the page showing.
enum KeyVoxKeyboardPages {
    static func key(_ label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    static func open(_ page: String, in app: XCUIApplication) throws {
        guard current(app) != page else { return }
        switch page {
        case "letters":
            try tap("ABC", in: app)
        case "numbers":
            try tap("Number Symbols", in: app)
        default:
            if current(app) != "numbers" { try tap("Number Symbols", in: app) }
            try tap("Alternate Symbols", in: app)
        }
    }

    static func current(_ app: XCUIApplication) -> String {
        if key("q", in: app).exists || key("Q", in: app).exists { return "letters" }
        if key("1", in: app).exists { return "numbers" }
        if key("[", in: app).exists { return "symbols" }
        return "unknown"
    }

    private static func tap(_ label: String, in app: XCUIApplication) throws {
        let key = key(label, in: app)
        try XCTUnwrap(key.exists ? key : nil, "no \(label) key").tap()
        Thread.sleep(forTimeInterval: 0.3)
    }
}
