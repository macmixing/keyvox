import Foundation
import XCTest
@testable import KeyVox

final class UpdateFeedResolverTests: XCTestCase {
    func testResolveFallsBackToTrackedDefaultWhenOverrideMissing() throws {
        try withTemporaryDirectory { root in
            let missing = root.appendingPathComponent("missing.json")
            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: missing)
            assertConfigMatchesTrackedDefault(resolved)
        }
    }

    func testResolveUsesValidOverride() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            let payload = """
            {
              "owner": "owner-test",
              "repo": "repo-test"
            }
            """
            try payload.data(using: .utf8)!.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            XCTAssertTrue(resolved.owner == "owner-test")
            XCTAssertTrue(resolved.repo == "repo-test")
            XCTAssertTrue(resolved.allowedHosts.elementsEqual(UpdateFeedConfig.trackedDefault.allowedHosts))
        }
    }

    func testResolveFallsBackWhenOverrideJsonInvalid() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            try "not-json".data(using: .utf8)!.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            assertConfigMatchesTrackedDefault(resolved)
        }
    }

    func testResolveFallsBackWhenOwnerOrRepoEmpty() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            let json = "{\n  \"owner\": \"  \",\n  \"repo\": \"keyvox\"\n}"
            try json.data(using: .utf8)!.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            assertConfigMatchesTrackedDefault(resolved)
        }
    }

    private func assertConfigMatchesTrackedDefault(_ config: UpdateFeedConfig) {
        XCTAssertTrue(config.owner == UpdateFeedConfig.trackedDefault.owner)
        XCTAssertTrue(config.repo == UpdateFeedConfig.trackedDefault.repo)
        XCTAssertTrue(config.allowedHosts.elementsEqual(UpdateFeedConfig.trackedDefault.allowedHosts))
    }
}
