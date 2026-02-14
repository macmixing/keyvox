import Foundation

enum AppUpdateLogic {
    static func mapReleaseInfo(
        from release: GitHubLatestReleaseResponse,
        allowedHosts: [String]
    ) -> LatestReleaseInfo? {
        let normalizedVersion = normalizeVersionTag(release.tagName)
        guard !normalizedVersion.isEmpty else { return nil }

        let selectedDownloadURL: URL? = release.assets.first(where: { asset in
            asset.name.lowercased().hasSuffix(".dmg")
        }).flatMap { URL(string: $0.browserDownloadURL) } ?? URL(string: release.htmlURL)

        guard let selectedDownloadURL,
              hasAllowedHost(selectedDownloadURL, allowedHosts: allowedHosts) else {
            return nil
        }

        return LatestReleaseInfo(
            version: normalizedVersion,
            message: release.body,
            updateURL: selectedDownloadURL
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
