import Foundation

nonisolated enum AppUpdateServiceError: Error {
    case invalidHTTPResponse
    case httpError(statusCode: Int, body: String?)
    case invalidPolicyVersion
    case invalidReleaseVersion
    case missingRelease
}

nonisolated private struct AppStoreLookupResponse: Decodable {
    nonisolated struct Item: Decodable {
        let version: String
        let trackViewUrl: URL?
    }

    let results: [Item]
}

nonisolated private struct AppUpdateManifestPayload: Decodable {
    let minimumSupportedVersion: String
}

nonisolated struct AppUpdateService {
    private let urlSession: URLSession
    private let decoder: JSONDecoder

    init(
        urlSession: URLSession = .shared,
        decoder: JSONDecoder = JSONDecoder()
    ) {
        self.urlSession = urlSession
        self.decoder = decoder
    }

    func fetchLatestRelease() async throws -> AppStoreRelease {
        let (data, response) = try await urlSession.data(from: AppUpdateConfiguration.appStoreLookupURL)
        try validateHTTPResponse(response, data: data)
        let lookupResponse = try decoder.decode(AppStoreLookupResponse.self, from: data)

        guard let item = lookupResponse.results.first else {
            throw AppUpdateServiceError.missingRelease
        }

        guard let version = AppVersion(item.version) else {
            throw AppUpdateServiceError.invalidReleaseVersion
        }

        return AppStoreRelease(
            version: version,
            storeURL: item.trackViewUrl ?? AppUpdateConfiguration.fallbackAppStoreURL
        )
    }

    func fetchPolicy() async throws -> AppUpdatePolicy {
        let (data, response) = try await urlSession.data(from: AppUpdateConfiguration.policyManifestURL)
        try validateHTTPResponse(response, data: data)
        let payload = try decoder.decode(AppUpdateManifestPayload.self, from: data)

        guard let minimumSupportedVersion = AppVersion(payload.minimumSupportedVersion) else {
            throw AppUpdateServiceError.invalidPolicyVersion
        }

        return AppUpdatePolicy(minimumSupportedVersion: minimumSupportedVersion)
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppUpdateServiceError.invalidHTTPResponse
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let responseBody = data.isEmpty ? nil : String(data: data, encoding: .utf8)
            throw AppUpdateServiceError.httpError(statusCode: httpResponse.statusCode, body: responseBody)
        }
    }
}
