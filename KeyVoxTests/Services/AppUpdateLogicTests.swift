import Foundation
import Testing
@testable import KeyVox

struct AppUpdateLogicTests {
    @Test
    func normalizeVersionTagStripsLeadingV() {
        #expect(AppUpdateLogic.normalizeVersionTag("v1.2.3") == "1.2.3")
        #expect(AppUpdateLogic.normalizeVersionTag("  V2.0.0 ") == "2.0.0")
        #expect(AppUpdateLogic.normalizeVersionTag("1.0") == "1.0")
    }

    @Test
    func compareVersionStringsHandlesDifferentLengths() {
        #expect(AppUpdateLogic.compareVersionStrings("1.2.0", "1.1.9") == 1)
        #expect(AppUpdateLogic.compareVersionStrings("1.2", "1.2.0") == 0)
        #expect(AppUpdateLogic.compareVersionStrings("1.2.0", "1.2.1") == -1)
    }

    @Test
    func hasAllowedHostAcceptsExactAndSubdomain() {
        let allowed = ["github.com"]
        #expect(AppUpdateLogic.hasAllowedHost(URL(string: "https://github.com/macmixing/keyvox")!, allowedHosts: allowed))
        #expect(AppUpdateLogic.hasAllowedHost(URL(string: "https://api.github.com/repos/macmixing/keyvox")!, allowedHosts: ["api.github.com"]))
        #expect(!AppUpdateLogic.hasAllowedHost(URL(string: "https://example.com/release")!, allowedHosts: allowed))
    }

    @Test
    func mapReleaseInfoPrefersDmgAsset() throws {
        let fixture = try loadFixtureData(named: "latest_with_dmg")
        let release = try JSONDecoder().decode(GitHubLatestReleaseResponse.self, from: fixture)

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        #expect(mapped != nil)
        #expect(mapped?.version == "1.2.0")
        #expect(mapped?.updateURL.absoluteString.contains(".dmg") == true)
    }

    @Test
    func mapReleaseInfoFallsBackToHtmlWhenNoDmg() throws {
        let fixture = try loadFixtureData(named: "latest_without_dmg")
        let release = try JSONDecoder().decode(GitHubLatestReleaseResponse.self, from: fixture)

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        #expect(mapped != nil)
        #expect(mapped?.updateURL.absoluteString == release.htmlURL)
    }

    @Test
    func mapReleaseInfoRejectsNonAllowlistedHost() {
        let release = GitHubLatestReleaseResponse(
            tagName: "1.2.0",
            body: "Release",
            htmlURL: "https://malicious.example.com/bad",
            assets: []
        )

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        #expect(mapped == nil)
    }
}
