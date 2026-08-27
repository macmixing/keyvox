import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum PromotionManifestSource: Sendable {
    case remote(URL)
    case bundled
}

public actor PromotionManifestRepository {
    private let source: PromotionManifestSource
    private let stateStore: PromotionStateStore
    private let session: URLSession

    public init(
        source: PromotionManifestSource,
        stateStore: PromotionStateStore,
        session: URLSession = .shared
    ) {
        self.source = source
        self.stateStore = stateStore
        self.session = session
    }

    public static func startupManifest(
        source: PromotionManifestSource,
        stateStore: PromotionStateStore
    ) -> PromotionManifest? {
        switch source {
        case .bundled:
            return try? PromotionManifestDecoder.decode(bundledManifestData())
        case .remote:
            if let cachedData = stateStore.cachedManifestData(),
               let cachedManifest = try? PromotionManifestDecoder.decode(cachedData) {
                return cachedManifest
            }
            return try? PromotionManifestDecoder.decode(bundledManifestData())
        }
    }

    public func loadManifest() async throws -> PromotionManifest {
        switch source {
        case .bundled:
            return try PromotionManifestDecoder.decode(Self.bundledManifestData())
        case .remote(let url):
            do {
                let (data, response) = try await session.data(from: url)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200...299).contains(httpResponse.statusCode) else {
                    throw URLError(.badServerResponse)
                }
                let manifest = try PromotionManifestDecoder.decode(data)
                stateStore.setCachedManifestData(data)
                return manifest
            } catch {
                if let cachedData = stateStore.cachedManifestData(),
                   let cachedManifest = try? PromotionManifestDecoder.decode(cachedData) {
                    return cachedManifest
                }
                return try PromotionManifestDecoder.decode(Self.bundledManifestData())
            }
        }
    }

    public static func bundledManifestData() throws -> Data {
        guard let url = Bundle.module.url(forResource: "campaigns", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try Data(contentsOf: url)
    }
}
