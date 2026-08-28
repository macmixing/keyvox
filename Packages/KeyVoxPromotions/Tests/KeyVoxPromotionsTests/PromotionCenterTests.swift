import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest
@testable import KeyVoxPromotions

final class PromotionCenterTests: XCTestCase {
    @MainActor
    func testStartsWithCachedCampaignAndDefersRemoteCampaignUntilNextInitialization() async throws {
        let suiteName = "KeyVoxPromotionsCenterTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let stateStore = PromotionStateStore(defaults: defaults, namespace: "Test")
        let cachedManifest = makeManifest(id: "cached", message: "Cached message")
        stateStore.setCachedManifestData(try JSONEncoder().encode(cachedManifest))

        let source = PromotionManifestSource.remote(
            URL(string: "https://example.com/campaigns.json")!
        )
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [UpdatedManifestURLProtocol.self]
        let repository = PromotionManifestRepository(
            source: source,
            stateStore: stateStore,
            session: URLSession(configuration: configuration)
        )
        let initialManifest = try XCTUnwrap(
            PromotionManifestRepository.startupManifest(
                source: source,
                stateStore: stateStore
            )
        )
        let center = PromotionCenter(
            repository: repository,
            stateStore: stateStore,
            audience: PromotionAudience(platform: .iOS, appVersion: "1.0.0"),
            initialManifest: initialManifest
        )

        XCTAssertEqual(center.currentCampaign?.id, "cached")

        center.refresh()
        let refreshedManifest = try await waitForCachedCampaign(
            id: "updated",
            stateStore: stateStore
        )

        XCTAssertEqual(refreshedManifest.campaigns.first?.message, "Updated message")
        XCTAssertEqual(center.currentCampaign?.id, "cached")

        let nextCenter = PromotionCenter(
            repository: repository,
            stateStore: stateStore,
            audience: PromotionAudience(platform: .iOS, appVersion: "1.0.0"),
            initialManifest: PromotionManifestRepository.startupManifest(
                source: source,
                stateStore: stateStore
            )
        )

        XCTAssertEqual(nextCenter.currentCampaign?.id, "updated")
    }

    @MainActor
    private func waitForCachedCampaign(
        id: String,
        stateStore: PromotionStateStore
    ) async throws -> PromotionManifest {
        for _ in 0..<100 {
            if let data = stateStore.cachedManifestData(),
               let manifest = try? PromotionManifestDecoder.decode(data),
               manifest.campaigns.first?.id == id {
                return manifest
            }
            try await Task.sleep(for: .milliseconds(10))
        }
        return try XCTUnwrap(nil as PromotionManifest?, "Timed out waiting for refreshed manifest")
    }

    private func makeManifest(id: String, message: String) -> PromotionManifest {
        PromotionManifest(
            selection: PromotionSelectionPolicy(mode: .static),
            campaigns: [
                PromotionCampaign(
                    id: id,
                    targets: [PromotionTarget(platform: .iOS)],
                    icon: PromotionIcon(kind: .systemImage, name: "star"),
                    title: id,
                    message: message
                )
            ]
        )
    }
}

private final class UpdatedManifestURLProtocol: URLProtocol, @unchecked Sendable {
    private static let responseData = Data(
        """
        {
          "schemaVersion": 1,
          "selection": { "mode": "static" },
          "campaigns": [
            {
              "id": "updated",
              "targets": [{ "platform": "ios" }],
              "icon": { "kind": "systemImage", "name": "star" },
              "title": "updated",
              "message": "Updated message"
            }
          ]
        }
        """.utf8
    )

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
