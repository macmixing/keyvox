import Foundation

struct AppUpdateManifestLoader {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func loadManifest(from url: URL) async throws -> AppUpdateManifest {
        let (data, response) = try await session.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AppUpdateError.networkUnavailable
        }

        let manifest = try JSONDecoder().decode(AppUpdateManifest.self, from: data)
        let normalizedVersion = AppUpdateLogic.normalizeVersionTag(manifest.version)
        return AppUpdateManifest(
            version: normalizedVersion,
            assetName: manifest.assetName,
            sha256: manifest.sha256.lowercased(),
            byteSize: manifest.byteSize,
            bundleIdentifier: manifest.bundleIdentifier,
            minimumSupportedMacOS: manifest.minimumSupportedMacOS
        )
    }
}
