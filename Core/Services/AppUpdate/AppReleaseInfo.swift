import Foundation

enum AppInstallAssetKind: Equatable {
    case zip
    case manualOnly
}

struct AppUpdateManifest: Decodable, Equatable {
    let version: String
    let assetName: String
    let sha256: String
    let byteSize: Int64
    let bundleIdentifier: String
    let minimumSupportedMacOS: String?
}

struct AppReleaseInfo: Equatable {
    let version: String
    let message: String?
    let releasePageURL: URL
    let installAssetURL: URL?
    let installAssetName: String?
    let manifestAssetURL: URL?
    let installAssetKind: AppInstallAssetKind

    var isInstallableInApp: Bool {
        installAssetKind == .zip && installAssetURL != nil && manifestAssetURL != nil
    }
}
