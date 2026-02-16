import XCTest
import AppKit
@testable import KeyVox

@MainActor
final class WindowManagerOnboardingWindowLevelTests: XCTestCase {
    func testLowerOnboardingWindowForAccessibilityPromptSetsNormalLevel() {
        let manager = WindowManager.shared
        let window = NSWindow()
        window.level = .floating

        let originalWindow = manager.onboardingWindow
        manager.onboardingWindow = window
        defer {
            manager.onboardingWindow = originalWindow
        }

        manager.lowerOnboardingWindowForAccessibilityPrompt()

        XCTAssertEqual(manager.onboardingWindow?.level, .normal)
    }

    func testRestoreOnboardingWindowAfterAccessibilityGrantedSetsFloatingLevel() {
        let manager = WindowManager.shared
        let window = NSWindow()
        window.level = .normal

        let originalWindow = manager.onboardingWindow
        manager.onboardingWindow = window
        defer {
            manager.onboardingWindow = originalWindow
        }

        manager.restoreOnboardingWindowAfterAccessibilityGranted()

        XCTAssertEqual(manager.onboardingWindow?.level, .floating)
    }
}
