import Foundation

struct ModelInstallManifest: Codable, Equatable {
    let version: Int
    let ggmlSHA256: String
    let coreMLZipSHA256: String

    static let currentVersion = 2
    static let supportedVersions: Set<Int> = [1, 2]
}

nonisolated enum ModelArtifacts {
    static let ggmlBaseSHA256 = "60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe"
    static let coreMLZipSHA256 = "7e6ab77041942572f239b5b602f8aaa1c3ed29d73e3d8f20abea03a773541089"
    static let minGGMLBytes: Int64 = 90_000_000
}
