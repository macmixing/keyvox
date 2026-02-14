import Foundation
import AppKit
import Combine

struct GitHubReleaseAsset: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}

struct GitHubLatestReleaseResponse: Decodable {
    let tagName: String
    let body: String?
    let htmlURL: String
    let assets: [GitHubReleaseAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case body
        case htmlURL = "html_url"
        case assets
    }
}

struct LatestReleaseInfo {
    let version: String
    let message: String?
    let updateURL: URL
}

struct UpdatePrompt {
    let title: String
    let message: String
    let version: String?
    let build: String?
    let dismissButtonTitle: String
    let primaryButtonTitle: String?
    let onPrimaryAction: (() -> Void)?
    let onDismiss: () -> Void
}

@MainActor
final class AppUpdateService: ObservableObject {
    static let shared = AppUpdateService()

    @Published private(set) var latestRemoteInfo: LatestReleaseInfo?

    private let githubOwner = "macmixing"
    private let githubRepo = "keyvoxghost"
    private let defaultCheckInterval: TimeInterval = 60 * 60 * 24
    private let allowedHosts = ["api.github.com", "github.com"]
    private var updateTimer: Timer?
    private var suppressedUpdateIDThisSession: String?

    private init() {}

    private var latestReleaseURL: URL {
        URL(string: "https://api.github.com/repos/\(githubOwner)/\(githubRepo)/releases/latest")!
    }

    /// Starts the automatic update polling timer.
    func startUpdateTimer() {
        updateTimer?.invalidate()
        checkForUpdatesIfNeeded()
        restartUpdateTimerIfNeeded()
    }

    /// Stops update polling.
    func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    /// Automatic update check. Respects remote alert toggle and cooldown.
    func checkForUpdatesIfNeeded() {
        Task { [weak self] in
            await self?.performUpdateCheck(isManualCheck: false)
        }
    }

    /// Manual check from UI action. Bypasses cooldown.
    func checkForUpdatesManually() {
        Task { [weak self] in
            await self?.performUpdateCheck(isManualCheck: true)
        }
    }

    private func restartUpdateTimerIfNeeded() {
        updateTimer?.invalidate()
        updateTimer = Timer.scheduledTimer(withTimeInterval: defaultCheckInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkForUpdatesIfNeeded()
            }
        }
    }

    private func performUpdateCheck(isManualCheck: Bool) async {
        guard let remoteInfo = await fetchLatestVersionInfo() else { return }
        guard shouldOfferUpdate(remoteInfo: remoteInfo) else {
            if isManualCheck {
                showNoUpdatePrompt()
            }
            return
        }
        let updateID = "\(remoteInfo.version)+\(remoteInfo.updateURL.absoluteString)"
        let cooldown = max(defaultCheckInterval, 1)

        // If user pressed "Later", suppress repeats for this app session.
        if !isManualCheck, suppressedUpdateIDThisSession == updateID {
            return
        }

        if !isManualCheck {
            let snoozedUntil = UserDefaults.standard.object(forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil) as? Date ?? .distantPast
            guard Date() >= snoozedUntil else { return }
        }

        guard let prompt = buildPrompt(from: remoteInfo, updateID: updateID, cooldown: cooldown) else { return }
        UpdatePromptManager.shared.show(prompt: prompt)
    }

    private func buildPrompt(from remoteInfo: LatestReleaseInfo, updateID: String, cooldown: TimeInterval) -> UpdatePrompt? {
        guard hasAllowedHost(remoteInfo.updateURL) else {
            #if DEBUG
            print("[AppUpdateService] Ignoring update URL outside allowlist: \(remoteInfo.updateURL.absoluteString)")
            #endif
            return nil
        }

        let fallbackMessage = "A new version of KeyVox is available. Please update for the best experience."
        let promptMessage: String
        if let body = remoteInfo.message, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptMessage = body
        } else {
            promptMessage = fallbackMessage
        }

        return UpdatePrompt(
            title: "KeyVox Update Available",
            message: promptMessage,
            version: remoteInfo.version,
            build: nil,
            dismissButtonTitle: "Later",
            primaryButtonTitle: "Download Update",
            onPrimaryAction: { [weak self] in
                NSWorkspace.shared.open(remoteInfo.updateURL)
                self?.snoozeAutoPrompt(for: cooldown, updateID: updateID)
            },
            onDismiss: { [weak self] in
                self?.snoozeAutoPrompt(for: cooldown, updateID: updateID)
            }
        )
    }

    private func showNoUpdatePrompt() {
        let local = localVersionInfo()
        let prompt = UpdatePrompt(
            title: "You're Up to Date",
            message: "KeyVox \(local.version) (\(local.build)) is currently the latest version.",
            version: local.version,
            build: local.build,
            dismissButtonTitle: "OK",
            primaryButtonTitle: nil,
            onPrimaryAction: nil,
            onDismiss: {}
        )
        UpdatePromptManager.shared.show(prompt: prompt)
    }

    private func localVersionInfo() -> (version: String, build: String) {
        let version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown"
        let build = (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "Unknown"
        return (version, build)
    }

    private func snoozeAutoPrompt(for cooldown: TimeInterval, updateID: String) {
        let now = Date()
        UserDefaults.standard.set(now, forKey: UserDefaultsKeys.App.updateAlertLastShown)
        UserDefaults.standard.set(now.addingTimeInterval(cooldown), forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil)
        suppressedUpdateIDThisSession = updateID
    }

    private func fetchLatestVersionInfo() async -> LatestReleaseInfo? {
        do {
            var request = URLRequest(url: latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("KeyVox/\(localVersionInfo().version)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse,
                  (200...299).contains(httpResponse.statusCode) else {
                #if DEBUG
                if let httpResponse = response as? HTTPURLResponse {
                    print("[AppUpdateService] GitHub API returned status \(httpResponse.statusCode)")
                }
                #endif
                return nil
            }

            let release = try JSONDecoder().decode(GitHubLatestReleaseResponse.self, from: data)
            guard let info = mapReleaseInfo(from: release) else { return nil }
            latestRemoteInfo = info
            return info
        } catch {
            #if DEBUG
            print("[AppUpdateService] Failed to fetch GitHub release info: \(error)")
            #endif
            return nil
        }
    }

    private func mapReleaseInfo(from release: GitHubLatestReleaseResponse) -> LatestReleaseInfo? {
        let normalizedVersion = normalizeVersionTag(release.tagName)
        guard !normalizedVersion.isEmpty else { return nil }

        let selectedDownloadURL: URL? = release.assets.first(where: { asset in
            asset.name.lowercased().hasSuffix(".dmg")
        }).flatMap { URL(string: $0.browserDownloadURL) } ?? URL(string: release.htmlURL)

        guard let selectedDownloadURL,
              hasAllowedHost(selectedDownloadURL) else {
            #if DEBUG
            print("[AppUpdateService] No allowed GitHub download URL for release \(release.tagName)")
            #endif
            return nil
        }

        return LatestReleaseInfo(
            version: normalizedVersion,
            message: release.body,
            updateURL: selectedDownloadURL
        )
    }

    private func shouldOfferUpdate(remoteInfo: LatestReleaseInfo) -> Bool {
        guard let localVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }

        let normalizedLocalVersion = normalizeVersionTag(localVersion)
        return compareVersionStrings(remoteInfo.version, normalizedLocalVersion) > 0
    }

    private func hasAllowedHost(_ url: URL) -> Bool {
        guard let host = url.host?.lowercased() else { return false }
        for allowedHost in allowedHosts {
            if host == allowedHost || host.hasSuffix(".\(allowedHost)") {
                return true
            }
        }
        return false
    }

    private func normalizeVersionTag(_ version: String) -> String {
        let trimmed = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.lowercased().hasPrefix("v") {
            return String(trimmed.dropFirst())
        }
        return trimmed
    }

    /// Returns 1 if `v1 > v2`, -1 if `v1 < v2`, 0 if equal.
    private func compareVersionStrings(_ v1: String, _ v2: String) -> Int {
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

    /// For testing: clears the update prompt cooldown.
    static func resetLastShown() {
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.App.updateAlertLastShown)
        UserDefaults.standard.removeObject(forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil)
    }
}
