import Foundation
import XCTest
@testable import KeyVox

final class PastePoliciesStabilityTests: XCTestCase {
    func testMenuTrustPolicyMatchesPreFixBehavior() {
        XCTAssertTrue(
            PastePolicies.shouldTrustMenuSuccessWithoutAXVerification(bundleID: "com.apple.MobileSMS")
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
        XCTAssertTrue(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.apple.MobileSMS"
            ) == .multiline
        )

        XCTAssertTrue(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.microsoft.VSCode"
            ) == .singleLineInline
        )
        XCTAssertTrue(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.openai.codex"
            ) == .singleLineInline
        )
        XCTAssertTrue(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.google.antigravity"
            ) == .singleLineInline
        )
        XCTAssertTrue(
            PastePolicies.listRenderMode(
                forAXRole: "AXTextField",
                bundleID: "com.exafunction.windsurf"
            ) == .singleLineInline
        )
    }
}
