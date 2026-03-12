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

    func testMapReleaseInfoPrefersZipWhenManifestIsPresent() throws {
        let release = GitHubLatestReleaseResponse(
            tagName: "v1.2.0",
            body: "Release notes",
            htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v1.2.0",
            assets: [
                GitHubReleaseAsset(
                    name: "KeyVox-1.2.0.zip",
                    browserDownloadURL: "https://github.com/macmixing/keyvox/releases/download/v1.2.0/KeyVox-1.2.0.zip"
                ),
                GitHubReleaseAsset(
                    name: AppUpdateLogic.manifestAssetName,
                    browserDownloadURL: "https://github.com/macmixing/keyvox/releases/download/v1.2.0/keyvox-update-manifest.json"
                ),
                GitHubReleaseAsset(
                    name: "KeyVox-1.2.0.dmg",
                    browserDownloadURL: "https://github.com/macmixing/keyvox/releases/download/v1.2.0/KeyVox-1.2.0.dmg"
                )
            ]
        )

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        XCTAssertNotNil(mapped)
        XCTAssertEqual(mapped?.version, "1.2.0")
        XCTAssertTrue(mapped?.installAssetURL?.absoluteString.contains(".zip") ?? false)
        XCTAssertEqual(mapped?.installAssetKind, .zip)
    }

    func testMapReleaseInfoFallsBackToManualOnlyWhenManifestMissing() throws {
        let release = GitHubLatestReleaseResponse(
            tagName: "v1.2.0",
            body: "Release notes",
            htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v1.2.0",
            assets: [
                GitHubReleaseAsset(
                    name: "KeyVox-1.2.0.zip",
                    browserDownloadURL: "https://github.com/macmixing/keyvox/releases/download/v1.2.0/KeyVox-1.2.0.zip"
                )
            ]
        )

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        XCTAssertTrue(mapped != nil)
        XCTAssertTrue(mapped?.releasePageURL.absoluteString == release.htmlURL)
        XCTAssertTrue(mapped?.installAssetURL == nil)
        XCTAssertTrue(mapped?.installAssetKind == .manualOnly)
    }

    func testMapReleaseInfoFallsBackToManualOnlyWhenMultipleZipAssetsExist() {
        let release = GitHubLatestReleaseResponse(
            tagName: "v1.2.0",
            body: "Release notes",
            htmlURL: "https://github.com/macmixing/keyvox/releases/tag/v1.2.0",
            assets: [
                GitHubReleaseAsset(
                    name: "KeyVox-1.2.0-arm64.zip",
                    browserDownloadURL: "https://github.com/macmixing/keyvox/releases/download/v1.2.0/KeyVox-1.2.0-arm64.zip"
                ),
                GitHubReleaseAsset(
                    name: "KeyVox-1.2.0-universal.zip",
                    browserDownloadURL: "https://github.com/macmixing/keyvox/releases/download/v1.2.0/KeyVox-1.2.0-universal.zip"
                ),
                GitHubReleaseAsset(
                    name: AppUpdateLogic.manifestAssetName,
                    browserDownloadURL: "https://github.com/macmixing/keyvox/releases/download/v1.2.0/keyvox-update-manifest.json"
                )
            ]
        )

        let mapped = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: ["github.com", "api.github.com"])
        XCTAssertTrue(mapped?.installAssetURL == nil)
        XCTAssertTrue(mapped?.installAssetKind == .manualOnly)
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

    func testAppUpdatePathsSanitizesVersionForReleaseDirectory() {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppUpdatePaths(fileManager: .default, rootDirectory: rootURL)

        let releaseURL = paths.releaseDirectoryURL(for: "../1.2.3/../../evil")

        XCTAssertTrue(releaseURL.path.hasPrefix(rootURL.path))
        XCTAssertTrue(releaseURL.lastPathComponent == "1.2.3evil")
    }

    func testAppUpdatePathsFallsBackForDotOnlyVersion() {
        let rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let paths = AppUpdatePaths(fileManager: .default, rootDirectory: rootURL)

        let releaseURL = paths.releaseDirectoryURL(for: ".....")

        XCTAssertTrue(releaseURL.path.hasPrefix(rootURL.path))
        XCTAssertTrue(releaseURL.lastPathComponent == "unknown-version")
    }
}
