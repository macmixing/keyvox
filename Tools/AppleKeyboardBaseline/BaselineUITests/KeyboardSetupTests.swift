import XCTest

/// Adds a third-party keyboard in the Settings app and allows it Full Access, so a fresh
/// simulator can run the typing replay against that keyboard.
///
/// Run with `TEST_RUNNER_SETUP_KEYBOARD_NAME` set to the keyboard's display name.
final class KeyboardSetupTests: XCTestCase {
    func testEnableThirdPartyKeyboard() throws {
        let keyboardName = try XCTUnwrap(
            ProcessInfo.processInfo.environment["SETUP_KEYBOARD_NAME"],
            "SETUP_KEYBOARD_NAME is not set"
        )
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.terminate()
        settings.launch()

        try tap(labeled: "General", in: settings)
        try tap(labeled: "Keyboard", in: settings)
        let keyboardsRow = settings.cells["KEYBOARDS"]
        XCTAssertTrue(keyboardsRow.waitForExistence(timeout: 10))
        keyboardsRow.tap()

        if element(labeled: keyboardName, in: settings).waitForExistence(timeout: 3) == false {
            let addKeyboard = settings.descendants(matching: .any)
                .matching(NSPredicate(format: "label BEGINSWITH %@", "Add New Keyboard"))
                .firstMatch
            XCTAssertTrue(addKeyboard.waitForExistence(timeout: 10))
            addKeyboard.tap()
            try tap(labeled: keyboardName, in: settings, scrolling: true)
        }

        try tap(labeled: keyboardName, in: settings)
        let fullAccess = settings.switches.firstMatch
        XCTAssertTrue(fullAccess.waitForExistence(timeout: 5))
        if (fullAccess.value as? String) != "1" {
            fullAccess.tap()
            let allow = settings.alerts.buttons["Allow"]
            if allow.waitForExistence(timeout: 5) {
                allow.tap()
            }
        }
        XCTAssertEqual(settings.switches.firstMatch.value as? String, "1")
    }

    private func element(labeled label: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", label))
            .firstMatch
    }

    private func tap(labeled label: String, in app: XCUIApplication, scrolling: Bool = false) throws {
        let target = element(labeled: label, in: app)
        if scrolling {
            var swipes = 0
            while (target.exists == false || target.isHittable == false), swipes < 60 {
                app.swipeUp(velocity: .fast)
                swipes += 1
            }
        }
        XCTAssertTrue(target.waitForExistence(timeout: 10), "\(label) not found")
        target.tap()
    }
}
