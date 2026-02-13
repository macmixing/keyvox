import Foundation
import AppKit
import Combine

///
/// Remote JSON schema:
/// {
///   "build": "1",
///   "version": "1.0.1",
///   "updateURL": "https://keyvox.app/builds/KeyVox.dmg",
///   "updateAlert": true,
///   "updateCheckInterval": 10800,
///   "updateTitle": "KeyVox Update Available!",
///   "message": "A new version of KeyVox is available! Please update for the best experience!"
/// }
struct AppVersionInfo: Codable {
    let build: String
    let version: String
    let updateURL: String
    let updateAlert: Bool?
    let updateTitle: String?
    let message: String?
    let updateCheckInterval: TimeInterval?
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

    @Published private(set) var latestRemoteInfo: AppVersionInfo?

    private let versionURL = URL(string: "https://keyvox.app/config/version.json")!
    private let defaultCheckInterval: TimeInterval = 60 * 60 * 24
    private let allowedHosts = ["keyvox.app", "apps.apple.com"]
    private var updateTimer: Timer?
    private var suppressedUpdateIDThisSession: String?

    private init() {}

    private var checkInterval: TimeInterval {
        latestRemoteInfo?.updateCheckInterval ?? defaultCheckInterval
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
        updateTimer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
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
        let updateID = "\(remoteInfo.version)+\(remoteInfo.build)"
        let cooldown = max(remoteInfo.updateCheckInterval ?? defaultCheckInterval, 1)

        // If user pressed "Later", suppress repeats for this app session.
        if !isManualCheck, suppressedUpdateIDThisSession == updateID {
            return
        }

        if !isManualCheck {
            let snoozedUntil = UserDefaults.standard.object(forKey: UserDefaultsKeys.App.updateAlertSnoozedUntil) as? Date ?? .distantPast
            guard Date() >= snoozedUntil else { return }

            if let alertEnabled = remoteInfo.updateAlert, !alertEnabled {
                return
            }
        }

        guard let prompt = buildPrompt(from: remoteInfo, updateID: updateID, cooldown: cooldown) else { return }
        UpdatePromptManager.shared.show(prompt: prompt)
    }

    private func buildPrompt(from remoteInfo: AppVersionInfo, updateID: String, cooldown: TimeInterval) -> UpdatePrompt? {
        guard let updateURL = URL(string: remoteInfo.updateURL),
              hasAllowedHost(updateURL) else {
            #if DEBUG
            print("[AppUpdateService] Ignoring update URL outside allowlist: \(remoteInfo.updateURL)")
            #endif
            return nil
        }

        return UpdatePrompt(
            title: remoteInfo.updateTitle ?? "KeyVox Update Available",
            message: remoteInfo.message ?? "A new version of KeyVox is available. Please update for the best experience.",
            version: remoteInfo.version,
            build: remoteInfo.build,
            dismissButtonTitle: "Later",
            primaryButtonTitle: "Download Update",
            onPrimaryAction: { [weak self] in
                NSWorkspace.shared.open(updateURL)
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

    private func fetchLatestVersionInfo() async -> AppVersionInfo? {
        do {
            let previousInterval = checkInterval
            let (data, _) = try await URLSession.shared.data(from: versionURL)
            let info = try JSONDecoder().decode(AppVersionInfo.self, from: data)
            latestRemoteInfo = info

            if let newInterval = info.updateCheckInterval, newInterval != previousInterval {
                restartUpdateTimerIfNeeded()
            }

            return info
        } catch {
            #if DEBUG
            print("[AppUpdateService] Failed to fetch version info: \(error)")
            #endif
            return nil
        }
    }

    private func shouldOfferUpdate(remoteInfo: AppVersionInfo) -> Bool {
        guard let localVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let localBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String else {
            return false
        }

        if compareVersionStrings(remoteInfo.version, localVersion) > 0 {
            return true
        }

        if remoteInfo.version == localVersion {
            if let remoteBuildInt = Int(remoteInfo.build), let localBuildInt = Int(localBuild) {
                return remoteBuildInt > localBuildInt
            }
            return remoteInfo.build > localBuild
        }

        return false
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
