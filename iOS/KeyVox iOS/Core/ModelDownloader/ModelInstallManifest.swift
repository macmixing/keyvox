import Foundation

struct DictationModelInstallManifest: Codable, Equatable, Sendable {
    static let currentVersion = 1
    static let supportedVersions: Set<Int> = [1]

    let version: Int
    let artifactSHA256ByRelativePath: [String: String]

    init(version: Int = Self.currentVersion, artifactSHA256ByRelativePath: [String: String]) {
        self.version = version
        self.artifactSHA256ByRelativePath = artifactSHA256ByRelativePath
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        if let artifactSHA256ByRelativePath = try container.decodeIfPresent(
            [String: String].self,
            forKey: .artifactSHA256ByRelativePath
        ) {
            version = try container.decode(Int.self, forKey: .version)
            self.artifactSHA256ByRelativePath = artifactSHA256ByRelativePath
            return
        }

        let legacyContainer = try decoder.container(keyedBy: LegacyCodingKeys.self)
        version = try legacyContainer.decode(Int.self, forKey: .version)
        let ggmlSHA256 = try legacyContainer.decode(String.self, forKey: .ggmlSHA256)
        let coreMLZipSHA256 = try legacyContainer.decode(String.self, forKey: .coreMLZipSHA256)
        artifactSHA256ByRelativePath = [
            "ggml-base.bin": ggmlSHA256,
            "ggml-base-encoder.mlmodelc.zip": coreMLZipSHA256,
        ]
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(version, forKey: .version)
        try container.encode(artifactSHA256ByRelativePath, forKey: .artifactSHA256ByRelativePath)
    }

    private enum CodingKeys: String, CodingKey {
        case version
        case artifactSHA256ByRelativePath
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case version
        case ggmlSHA256
        case coreMLZipSHA256
    }
}

typealias ModelInstallManifest = DictationModelInstallManifest

enum ModelArtifacts {
    nonisolated static let ggmlBaseSHA256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"
    nonisolated static let coreMLZipSHA256 = "7e6ab77041942572f239b5b602f8aaa1c3ed29d73e3d8f20abea03a773541089"
    nonisolated static let minGGMLBytes: Int64 = 90_000_000
}
