import Foundation

struct PocketTTSInstallManifest: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let filename = "install-manifest.json"

    let version: Int
    let installedAt: Date
    let sourceRepository: String
    let artifactSizesByRelativePath: [String: Int64]

    init(
        version: Int = currentVersion,
        installedAt: Date = Date(),
        sourceRepository: String,
        artifactSizesByRelativePath: [String: Int64]
    ) {
        self.version = version
        self.installedAt = installedAt
        self.sourceRepository = sourceRepository
        self.artifactSizesByRelativePath = artifactSizesByRelativePath
    }
}
