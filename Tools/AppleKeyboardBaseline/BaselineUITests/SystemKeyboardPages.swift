import XCTest

/// Moves the system keyboard between its letter page, number page, and symbol page, and
/// names the page showing. The number page's symbol key has no stable label, so it is
/// found by position: directly above the number page's letters key.
enum SystemKeyboardPages {
    static func open(_ page: String, on keyboard: XCUIElement) throws {
        try showLetters(keyboard)
        guard page != "letters" else { return }
        try tap(keyboard.keys["more"].firstMatch, "no key opens the number page")
        guard page == "symbols" else { return }
        // One row above the letters key: rows sit as far apart as the number row and the row below it.
        let lettersKey = keyboard.keys["more"].firstMatch.frame
        let rowPitch = keyboard.keys["-"].firstMatch.frame.midY - keyboard.keys["1"].firstMatch.frame.midY
        keyboard.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: lettersKey.midX - keyboard.frame.minX, dy: lettersKey.midY - rowPitch - keyboard.frame.minY))
            .tap()
        Thread.sleep(forTimeInterval: 0.3)
        _ = try XCTUnwrap(current(keyboard) == "symbols" ? keyboard : nil, "the symbol page did not open")
    }

    static func current(_ keyboard: XCUIElement) -> String {
        if keyboard.keys["q"].exists || keyboard.keys["Q"].exists { return "letters" }
        if keyboard.keys["1"].exists { return "numbers" }
        if keyboard.keys["["].exists { return "symbols" }
        return "unknown"
    }

    private static func showLetters(_ keyboard: XCUIElement) throws {
        for _ in 0..<2 where current(keyboard) != "letters" {
            try tap(keyboard.keys["more"].firstMatch, "no key opens the letter page")
        }
    }

    private static func tap(_ key: XCUIElement?, _ failure: String) throws {
        try XCTUnwrap(key?.exists == true ? key : nil, failure).tap()
        Thread.sleep(forTimeInterval: 0.3)
    }
}
