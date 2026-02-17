import Foundation
import XCTest
@testable import KeyVox

final class AppUpdateLogicTests: XCTestCase {
    func testNormalizeVersionTagStripsLeadingV() {
        XCTAssertTrue(AppUpdateLogic.normalizeVersionTag("v1.2.3") == "1.2.3")
        XCTAssertTrue(AppUpdateLogic.normalizeVersionTag("  V2.0.0 ") == "2.0.0")
        XCTAssertTrue(AppUpdateLogic.normalizeVersionTag("1.0") == "1.0")
    }

    func testCompareVersionStringsHandlesDifferentLengths() {
        XCTAssertTrue(AppUpdateLogic.compareVersionStrings("1.2.0", "1.1.9") == 1)
        XCTAssertTrue(AppUpdateLogic.compareVersionStrings("1.2", "1.2.0") == 0)
        XCTAssertTrue(AppUpdateLogic.compareVersionStrings("1.2.0", "1.2.1") == -1)
    }

    func testHasAllowedHostAcceptsExactAndSubdomain() {
        let allowed = ["github.com"]
        XCTAssertTrue(AppUpdateLogic.hasAllowedHost(URL(string: "https://github.com/macmixing/keyvox")!, allowedHosts: allowed))
        XCTAssertTrue(AppUpdateLogic.hasAllowedHost(URL(string: "https://api.github.com/repos/macmixing/keyvox")!, allowedHosts: ["api.github.com"]))
        XCTAssertTrue(!AppUpdateLogic.hasAllowedHost(URL(string: "https://example.com/release")!, allowedHosts: allowed))
    }

    func testMapReleaseInfoPrefersDmgAsset() throws {
        let release = GitHubLatestReleaseResponse(
            tagName: "v1.2.0",
            body: "Release notes",
            htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v1.2.0",
            assets: [
                GitHubReleaseAsset(
                    name: "KeyVox-1.2.0.dmg",
                    browserDownloadURL: "https://github.com/macmixing/keyvox/releases/download/v1.2.0/KeyVox-1.2.0.dmg"
                )
            ]
        )

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        XCTAssertTrue(mapped != nil)
        XCTAssertTrue(mapped?.version == "1.2.0")
        XCTAssertTrue(mapped?.updateURL.absoluteString.contains(".dmg") == true)
    }

    func testMapReleaseInfoFallsBackToHtmlWhenNoDmg() throws {
        let release = GitHubLatestReleaseResponse(
            tagName: "v1.2.0",
            body: "Release notes",
            htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v1.2.0",
            assets: []
        )

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        XCTAssertTrue(mapped != nil)
        XCTAssertTrue(mapped?.updateURL.absoluteString == release.htmlURL)
    }

    func testMapReleaseInfoRejectsNonAllowlistedHost() {
        let release = GitHubLatestReleaseResponse(
            tagName: "1.2.0",
            body: "Release",
            htmlURL: "https://malicious.example.com/bad",
            assets: []
        )

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        XCTAssertTrue(mapped == nil)
    }
}
