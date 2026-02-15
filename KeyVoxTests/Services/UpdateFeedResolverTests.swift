import Foundation
import XCTest
@testable import KeyVox

final class UpdateFeedResolverTests: XCTestCase {
    func testResolveFallsBackToTrackedDefaultWhenOverrideMissing() throws {
        try withTemporaryDirectory { root in
            let missing = root.appendingPathComponent("missing.json")
            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: missing)
            XCTAssertTrue(resolved == .trackedDefault)
        }
    }

    func testResolveUsesValidOverride() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            let payload = UpdateFeedOverride(owner: "owner-test", repo: "repo-test")
            let data = try JSONEncoder().encode(payload)
            try data.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            XCTAssertTrue(resolved.owner == "owner-test")
            XCTAssertTrue(resolved.repo == "repo-test")
            XCTAssertTrue(resolved.allowedHosts == UpdateFeedConfig.trackedDefault.allowedHosts)
        }
    }

    func testResolveFallsBackWhenOverrideJsonInvalid() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            try "not-json".data(using: .utf8)!.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            XCTAssertTrue(resolved == .trackedDefault)
        }
    }

    func testResolveFallsBackWhenOwnerOrRepoEmpty() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            let json = "{\n  \"owner\": \"  \",\n  \"repo\": \"keyvox\"\n}"
            try json.data(using: .utf8)!.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            XCTAssertTrue(resolved == .trackedDefault)
        }
    }
}
