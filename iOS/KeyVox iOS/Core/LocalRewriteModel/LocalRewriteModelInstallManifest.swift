import Foundation

struct LocalRewriteModelInstallManifest: Codable, Equatable {
    let modelID: String
    let artifactFilename: String
    let sourceRepository: String
    let expectedSHA256: String
    let installedSHA256: String
    let fileSize: Int64
    let installedAt: Date
}
