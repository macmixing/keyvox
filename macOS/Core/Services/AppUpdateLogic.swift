import Foundation

enum AppUpdateLogic {
    static let manifestAssetName = "keyvox-update-manifest.json"

    static func mapReleaseInfo(
        from release: GitHubLatestReleaseResponse,
        allowedHosts: [String]
    ) -> AppReleaseInfo? {
        let normalizedVersion = normalizeVersionTag(release.tagName)
        guard !normalizedVersion.isEmpty else { return nil }

        guard let releasePageURL = URL(string: release.htmlURL),
              hasAllowedHost(releasePageURL, allowedHosts: allowedHosts) else {
            return nil
        }

        let zipAssets = release.assets.filter { asset in
            asset.name.lowercased().hasSuffix(".zip")
        }
        // Fail closed when multiple ZIP assets are present. The manifest is
        // loaded later in the pipeline, so release parsing only auto-installs
        // when there is a single unambiguous ZIP candidate here.
        let zipAsset = zipAssets.count == 1 ? zipAssets.first : nil
        let manifestAsset = release.assets.first(where: { asset in
            asset.name.caseInsensitiveCompare(manifestAssetName) == .orderedSame
        })

        let installAssetURL = zipAsset.flatMap { URL(string: $0.browserDownloadURL) }
        let manifestAssetURL = manifestAsset.flatMap { URL(string: $0.browserDownloadURL) }
        let hasValidInstallAssets =
            installAssetURL != nil &&
            manifestAssetURL != nil &&
            installAssetURL.map { hasAllowedHost($0, allowedHosts: allowedHosts) } == true &&
            manifestAssetURL.map { hasAllowedHost($0, allowedHosts: allowedHosts) } == true

        return AppReleaseInfo(
            version: normalizedVersion,
            message: release.body,
            releasePageURL: releasePageURL,
            installAssetURL: hasValidInstallAssets ? installAssetURL : nil,
            installAssetName: hasValidInstallAssets ? zipAsset?.name : nil,
            manifestAssetURL: hasValidInstallAssets ? manifestAssetURL : nil,
            installAssetKind: hasValidInstallAssets ? .zip : .manualOnly
        )
    }

    static func normalizeVersionTag(_ version: String) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    /// Returns 1 if `v1 > v2`, -1 if `v1 < v2`, 0 if equal.
    static func compareVersionStrings(_ v1: String, _ v2: String) -> Int {
        let a = v1.split(separator: ".").map { Int($0) ?? 0 }
        let b = v2.split(separator: ".").map { Int($0) ?? 0 }
        let maxCount = max(a.count, b.count)

        for i in 0..<maxCount {
            let ai = i < a.count ? a[i] : 0
            let bi = i < b.count ? b[i] : 0
            if ai > bi { return 1 }
            if ai < bi { return -1 }
        }

        return 0
    }

    static func hasAllowedHost(_ url: URL, allowedHosts: [String]) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        for allowedHost in allowedHosts {
            if host == allowedHost || host.hasSuffix(".\(allowedHost)") {
                return true
            }
        }
        return false
    }
}
