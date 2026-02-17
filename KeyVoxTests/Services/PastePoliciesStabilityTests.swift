import Foundation
import XCTest
@testable import KeyVox

final class PastePoliciesStabilityTests: XCTestCase {
    func testMenuTrustPolicyMatchesPreFixBehavior() {
        XCTAssertTrue(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.apple.MobileSMS")
        )
        XCTAssertTrue(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.apple.iWork.Numbers")
        )

        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: nil)
        )
        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.microsoft.VSCode")
        )
        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.openai.codex")
        )
        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.google.antigravity")
        )
        XCTAssertFalse(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.exafunction.windsurf")
        )
    }

    func testListMultilineOverridePolicyMatchesPreFixBehavior() {
        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.apple.MobileSMS"
            ),
            equals: .multiline
        )

        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.microsoft.VSCode"
            ),
            equals: .singleLineInline
        )
        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.openai.codex"
            ),
            equals: .singleLineInline
        )
        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.google.antigravity"
            ),
            equals: .singleLineInline
        )
        assertListRenderMode(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.exafunction.windsurf"
            ),
            equals: .singleLineInline
        )
    }

    func testElectronFrameworkDetectionDoesNotDependOnBundleIDAllowlist() {
        XCTAssertTrue(
            PasteService.containsElectronFramework(
                frameworkNames: ["App.framework", "Electron Framework.framework", "Squirrel.framework"]
            )
        )

        XCTAssertFalse(
            PasteService.containsElectronFramework(
                frameworkNames: ["App.framework", "Sparkle.framework", "WebKit.framework"]
            )
        )
    }

    private func assertListRenderMode(_ actual: ListRenderMode, equals expected: ListRenderMode) {
        switch (actual, expected) {
        case (.multiline, .multiline), (.singleLineInline, .singleLineInline):
            XCTAssertTrue(true)
        default:
            XCTFail("Unexpected list render mode")
        }
    }
}
