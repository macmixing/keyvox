import Foundation
import KeyVoxStyleRewrite
import Testing
@testable import KeyVox_iOS

struct StyleRewriteLatestArtifactStoreTests {
    @Test func latestDictationArtifactRoundTripsThroughDefaults() throws {
        let harness = try makeStoreHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.suiteName) }

        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: "raw",
            baseText: "base",
            selectedText: "styled",
            selectedStyleIdentifier: "polished-dictation",
            variants: [],
            inferenceDuration: 0.1,
            textTransformationDuration: 0.2,
            createdAt: Date()
        )

        harness.store.save(artifact)

        let decoded = try #require(harness.store.artifact())
        #expect(decoded == artifact)
    }

    @Test func clearRemovesLatestDictationArtifact() throws {
        let harness = try makeStoreHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.suiteName) }

        let artifact = DictationUtteranceArtifact(
            id: UUID(),
            rawText: "raw",
            baseText: "base",
            selectedText: "styled",
            selectedStyleIdentifier: nil,
            variants: [],
            inferenceDuration: 0.1,
            textTransformationDuration: 0,
            createdAt: Date()
        )

        harness.store.save(artifact)
        harness.store.clear()

        #expect(harness.store.data() == nil)
        #expect(harness.store.artifact() == nil)
    }

    @Test func artifactReturnsNilForInvalidStoredData() throws {
        let harness = try makeStoreHarness()
        defer { harness.defaults.removePersistentDomain(forName: harness.suiteName) }

        harness.defaults.set(Data("not-json".utf8), forKey: StyleRewriteLatestArtifactStore.latestArtifactDataKeyForTests)

        #expect(harness.store.artifact() == nil)
    }

    private func makeStoreHarness() throws -> (
        suiteName: String,
        defaults: UserDefaults,
        store: StyleRewriteLatestArtifactStore
    ) {
        let suiteName = "StyleRewriteLatestArtifactStoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (
            suiteName,
            defaults,
            StyleRewriteLatestArtifactStore(defaults: defaults)
        )
    }
}
