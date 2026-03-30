import Foundation

struct DictationModelInstallManifest: Codable, Equatable {
    let version: Int
    let artifactSHA256ByRelativePath: [String: String]

    static let currentVersion = 1
    static let supportedVersions: Set<Int> = [currentVersion]

    private enum CodingKeys: String, CodingKey {
        case version
        case artifactSHA256ByRelativePath
    }

    nonisolated init(version: Int, artifactSHA256ByRelativePath: [String: String]) {
        self.version = version
        self.artifactSHA256ByRelativePath = artifactSHA256ByRelativePath
    }

    nonisolated init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            version: try container.decode(Int.self, forKey: .version),
            artifactSHA256ByRelativePath: try container.decode(
                [String: String].self,
                forKey: .artifactSHA256ByRelativePath
            )
        )
    }

    nonisolated func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(artifactSHA256ByRelativePath, forKey: .artifactSHA256ByRelativePath)
    }
}
