import Foundation

nonisolated struct DictationModelInstallManifest: Codable, Equatable {
    let version: Int
    let artifactSHA256ByRelativePath: [String: String]

    static let currentVersion = 1
    static let supportedVersions: Set<Int> = [currentVersion]
}
