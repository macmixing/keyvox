import XCTest

/// Switches the focused text view's keyboard with the system "Next keyboard" button
/// until an element labeled `markerLabel` (a key only that keyboard has) appears.
enum KeyboardSwitcher {
    static func switchToKeyboard(withKey markerLabel: String, in app: XCUIApplication) -> Bool {
        let marker = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", markerLabel))
            .firstMatch
        for _ in 0..<4 {
            if marker.waitForExistence(timeout: 2) { return true }
            let nextKeyboard = app.buttons["Next keyboard"]
            guard nextKeyboard.waitForExistence(timeout: 3) else { return false }
            nextKeyboard.tap()
        }
        return marker.waitForExistence(timeout: 3)
    }

    /// Switches back to the system keyboard the same way, if another keyboard is showing.
    static func switchToSystemKeyboard(in app: XCUIApplication) -> Bool {
        let systemKey = app.keyboards.keys["q"]
        for _ in 0..<4 {
            if systemKey.waitForExistence(timeout: 2) { return true }
            let nextKeyboard = app.buttons["Next keyboard"]
            guard nextKeyboard.waitForExistence(timeout: 3) else { return false }
            nextKeyboard.tap()
        }
        return systemKey.waitForExistence(timeout: 3)
    }
}
