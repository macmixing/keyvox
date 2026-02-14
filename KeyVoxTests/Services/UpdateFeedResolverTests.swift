import Foundation
import Testing
@testable import KeyVox

struct UpdateFeedResolverTests {
    @Test
    func resolveFallsBackToTrackedDefaultWhenOverrideMissing() throws {
        try withTemporaryDirectory { root in
            let missing = root.appendingPathComponent("missing.json")
            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: missing)
            #expect(resolved == .trackedDefault)
        }
    }

    @Test
    func resolveUsesValidOverride() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            let payload = UpdateFeedOverride(owner: "owner-test", repo: "repo-test")
            let data = try JSONEncoder().encode(payload)
            try data.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            #expect(resolved.owner == "owner-test")
            #expect(resolved.repo == "repo-test")
            #expect(resolved.allowedHosts == UpdateFeedConfig.trackedDefault.allowedHosts)
        }
    }

    @Test
    func resolveFallsBackWhenOverrideJsonInvalid() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            try "not-json".data(using: .utf8)!.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            #expect(resolved == .trackedDefault)
        }
    }

    @Test
    func resolveFallsBackWhenOwnerOrRepoEmpty() throws {
        try withTemporaryDirectory { root in
            let overrideURL = root.appendingPathComponent("update-feed.override.json")
            let json = "{\n  \"owner\": \"  \",\n  \"repo\": \"keyvox\"\n}"
            try json.data(using: .utf8)!.write(to: overrideURL)

            let resolved = UpdateFeedResolver.resolve(fileManager: .default, overrideFileURL: overrideURL)
            #expect(resolved == .trackedDefault)
        }
    }
}
