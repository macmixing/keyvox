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

    private let feedConfig: UpdateFeedConfig
    private let bundle: Bundle
    private let urlSession: URLSession
    private let defaultCheckInterval: TimeInterval = 60 * 60 * 24
    private var updateTimer: Timer?
    private var suppressedUpdateIDThisSession: String?
    private var autoPromptSnoozedUntilInSession: Date?

    init(
        feedConfig: UpdateFeedConfig? = nil,
        bundle: Bundle = .main,
        urlSession: URLSession = .shared
    ) {
        self.feedConfig = feedConfig ?? UpdateFeedResolver.resolve()
        self.bundle = bundle
        self.urlSession = urlSession
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
            if let snoozedUntil = autoPromptSnoozedUntilInSession, Date() < snoozedUntil {
                return
            }
        }

        if !isManualCheck {
            if let snoozedUntil = autoPromptSnoozedUntilInSession, Date() < snoozedUntil {
                return
            }
        }

        guard let prompt = buildPrompt(from: remoteInfo, updateID: updateID, cooldown: cooldown) else { return }
        UpdatePromptManager.shared.show(prompt: prompt)
    }

    private func buildPrompt(from remoteInfo: LatestReleaseInfo, updateID: String, cooldown: TimeInterval) -> UpdatePrompt? {
        guard AppUpdateLogic.hasAllowedHost(remoteInfo.updateURL, allowedHosts: feedConfig.allowedHosts) else {
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
        let version = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown"
        let build = (bundle.infoDictionary?["CFBundleVersion"] as? String) ?? "Unknown"
        return (version, build)
    }

    private func snoozeAutoPrompt(for cooldown: TimeInterval, updateID: String) {
        autoPromptSnoozedUntilInSession = Date().addingTimeInterval(cooldown)
        suppressedUpdateIDThisSession = updateID
    }

    private func fetchLatestVersionInfo() async -> LatestReleaseInfo? {
        do {
            var request = URLRequest(url: feedConfig.latestReleaseURL)
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            request.setValue("KeyVox/\(localVersionInfo().version)", forHTTPHeaderField: "User-Agent")

            let (data, response) = try await urlSession.data(for: request)
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
            guard let info = AppUpdateLogic.mapReleaseInfo(from: release, allowedHosts: feedConfig.allowedHosts) else {
                #if DEBUG
                print("[AppUpdateService] No allowed GitHub download URL for release \(release.tagName)")
                #endif
                return nil
            }
            latestRemoteInfo = info
            return info
        } catch {
            #if DEBUG
            print("[AppUpdateService] Failed to fetch GitHub release info: \(error)")
            #endif
            return nil
        }
    }

    private func shouldOfferUpdate(remoteInfo: LatestReleaseInfo) -> Bool {
        guard let localVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }

        let normalizedLocalVersion = AppUpdateLogic.normalizeVersionTag(localVersion)
        return AppUpdateLogic.compareVersionStrings(remoteInfo.version, normalizedLocalVersion) > 0
    }

    /// For testing: clears the update prompt cooldown.
    @MainActor
    static func resetLastShown() {
        AppUpdateService.shared.autoPromptSnoozedUntilInSession = nil
        AppUpdateService.shared.suppressedUpdateIDThisSession = nil
    }
}
