import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import KeyVoxPromotions

final class PromotionManifestRepositoryTests: XCTestCase {
    func testRemoteFailureFallsBackToLastValidCachedManifest() async throws {
        let suiteName = "KeyVoxPromotionsRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = PromotionStateStore(defaults: defaults, namespace: "Test")
        let cachedData = try PromotionManifestRepository.bundledManifestData()
        stateStore.setCachedManifestData(cachedData)
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailingURLProtocol.self]
        let repository = PromotionManifestRepository(
            source: .remote(URL(string: "https://example.com/campaigns.json")!),
            stateStore: stateStore,
            session: URLSession(configuration: configuration)
        )

        let manifest = try await repository.loadManifest()

        XCTAssertEqual(manifest.schemaVersion, PromotionManifest.supportedSchemaVersion)
        XCTAssertFalse(manifest.campaigns.isEmpty)
    }

    func testFirstRemoteFailureFallsBackToBundledManifest() async throws {
        let suiteName = "KeyVoxPromotionsRepositoryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = PromotionStateStore(defaults: defaults, namespace: "Test")
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [FailingURLProtocol.self]
        let repository = PromotionManifestRepository(
            source: .remote(URL(string: "https://example.com/campaigns.json")!),
            stateStore: stateStore,
            session: URLSession(configuration: configuration)
        )

        let manifest = try await repository.loadManifest()

        XCTAssertTrue(manifest.campaigns.contains { $0.id == "ios-compact-keys" })
    }
}

private final class FailingURLProtocol: URLProtocol, @unchecked Sendable {
    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
    }

    override func stopLoading() {}
}
