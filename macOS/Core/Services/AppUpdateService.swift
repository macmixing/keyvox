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

    @Published private(set) var latestRemoteInfo: AppReleaseInfo?

    private enum ReleaseNotesPreview {
        static let maxLines = 4
        static let maxCharacters = 240
    }

    private let feedConfig: UpdateFeedConfig
    private let bundle: Bundle
    private let urlSession: URLSession
    private let promptPresenter: UpdatePromptPresenting
    private let nowProvider: () -> Date
    private let defaultCheckInterval: TimeInterval
    private var updateTimer: Timer?
    private var suppressedUpdateIDThisSession: String?
    private var autoPromptSnoozedUntilInSession: Date?
    private var suppressNextAutomaticPrompt = false

    init(
        feedConfig: UpdateFeedConfig? = nil,
        bundle: Bundle = .main,
        urlSession: URLSession = .shared,
        promptPresenter: UpdatePromptPresenting? = nil,
        nowProvider: @escaping () -> Date = Date.init,
        checkInterval: TimeInterval = 60 * 60 * 24
    ) {
        self.feedConfig = feedConfig ?? UpdateFeedResolver.resolve()
        self.bundle = bundle
        self.urlSession = urlSession
        self.promptPresenter = promptPresenter ?? UpdatePromptManager.shared
        self.nowProvider = nowProvider
        self.defaultCheckInterval = max(checkInterval, 1)
    }

    // Keep teardown explicit to avoid synthesized deinit runtime issues in test host.
    deinit {}

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

    func fetchLatestReleaseInfo() async -> AppReleaseInfo? {
        await fetchLatestVersionInfo()
    }

    func shouldOfferUpdateToCurrentVersion(_ remoteInfo: AppReleaseInfo) -> Bool {
        shouldOfferUpdate(remoteInfo: remoteInfo)
    }

    func suppressNextAutomaticUpdatePrompt() {
        suppressNextAutomaticPrompt = true
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
        if isManualCheck {
            AppUpdateDisplayCoordinator.shared.captureManualCheckDisplay()
        }

        if !isManualCheck, suppressNextAutomaticPrompt {
            suppressNextAutomaticPrompt = false
            return
        }

        guard let remoteInfo = await fetchLatestVersionInfo() else {
            if isManualCheck {
                showUnavailableUpdatePrompt()
            }
            return
        }
        guard shouldOfferUpdate(remoteInfo: remoteInfo) else {
            if isManualCheck {
                showNoUpdatePrompt()
            }
            return
        }
        let updateID = "\(remoteInfo.version)+\(remoteInfo.releasePageURL.absoluteString)"
        let cooldown = max(defaultCheckInterval, 1)

        // If user pressed "Later", suppress repeats for this app session.
        if !isManualCheck, suppressedUpdateIDThisSession == updateID {
            if let snoozedUntil = autoPromptSnoozedUntilInSession, nowProvider() < snoozedUntil {
                return
            }
        }

        if !isManualCheck {
            if let snoozedUntil = autoPromptSnoozedUntilInSession, nowProvider() < snoozedUntil {
                return
            }
        }

        guard let prompt = buildPrompt(from: remoteInfo, updateID: updateID, cooldown: cooldown) else { return }
        if !isManualCheck {
            AppUpdateDisplayCoordinator.shared.captureAutomaticPromptDisplay()
        }
        promptPresenter.show(prompt: prompt)
    }

    private func buildPrompt(from remoteInfo: AppReleaseInfo, updateID: String, cooldown: TimeInterval) -> UpdatePrompt? {
        guard AppUpdateLogic.hasAllowedHost(remoteInfo.releasePageURL, allowedHosts: feedConfig.allowedHosts) else {
            #if DEBUG
            print("[AppUpdateService] Ignoring update URL outside allowlist: \(remoteInfo.releasePageURL.absoluteString)")
            #endif
            return nil
        }

        let fallbackMessage = "A new version of KeyVox is available. Please update for the best experience."
        let promptMessage: String
        if let body = remoteInfo.message, !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            promptMessage = summarizedReleaseBody(body) ?? fallbackMessage
        } else {
            promptMessage = fallbackMessage
        }

        return UpdatePrompt(
            title: "KeyVox Update Available",
            message: promptMessage,
            version: remoteInfo.version,
            build: nil,
            dismissButtonTitle: "Later",
            primaryButtonTitle: "Open Updater",
            onPrimaryAction: { [weak self] in
                AppUpdateCoordinator.shared.openWindow(for: remoteInfo)
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
        promptPresenter.show(prompt: prompt)
    }

    private func showUnavailableUpdatePrompt() {
        let prompt = UpdatePrompt(
            title: "Updates Temporarily Unavailable",
            message: "We're a little busy right now. Please check back later.",
            version: nil,
            build: nil,
            dismissButtonTitle: "OK",
            primaryButtonTitle: nil,
            onPrimaryAction: nil,
            onDismiss: {}
        )
        promptPresenter.show(prompt: prompt)
    }

    private func localVersionInfo() -> (version: String, build: String) {
        let version = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown"
        let build = (bundle.infoDictionary?["CFBundleVersion"] as? String) ?? "Unknown"
        return (version, build)
    }

    private func snoozeAutoPrompt(for cooldown: TimeInterval, updateID: String) {
        autoPromptSnoozedUntilInSession = nowProvider().addingTimeInterval(cooldown)
        suppressedUpdateIDThisSession = updateID
    }

    private func fetchLatestVersionInfo() async -> AppReleaseInfo? {
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

    private func shouldOfferUpdate(remoteInfo: AppReleaseInfo) -> Bool {
        guard let localVersion = bundle.infoDictionary?["CFBundleShortVersionString"] as? String else {
            return false
        }

        let normalizedLocalVersion = AppUpdateLogic.normalizeVersionTag(localVersion)
        return AppUpdateLogic.compareVersionStrings(remoteInfo.version, normalizedLocalVersion) > 0
    }

    func summarizedReleaseBodyForDisplay(_ body: String?) -> String {
        guard let body else {
            return "A new version of KeyVox is available."
        }
        return summarizedReleaseBody(body) ?? "A new version of KeyVox is available."
    }

    private func summarizedReleaseBody(_ body: String) -> String? {
        let normalized = body.replacingOccurrences(of: "\r\n", with: "\n")

        if let summarySection = extractSummarySection(from: normalized) {
            if let summaryPreview = truncateReleasePreview(summarySection) {
                return summaryPreview
            }
        }

        return truncateReleasePreview(normalized)
    }

    private func extractSummarySection(from body: String) -> String? {
        let lines = body.components(separatedBy: .newlines)
        guard let summaryHeadingIndex = lines.firstIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("##") else { return false }
            let headingText = trimmed
                .drop(while: { $0 == "#" })
                .trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: CharacterSet(charactersIn: ":"))
                .lowercased()
            return headingText == "summary"
        }) else {
            return nil
        }

        var summaryLines: [String] = []
        for line in lines.dropFirst(summaryHeadingIndex + 1) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                break
            }
            summaryLines.append(line)
        }

        let summary = summaryLines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return summary.isEmpty ? nil : summary
    }

    private func truncateReleasePreview(_ text: String) -> String? {
        let lines = text
            .components(separatedBy: .newlines)
            .map(sanitizeReleaseLine)
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }

        let hadMoreLines = lines.count > ReleaseNotesPreview.maxLines
        let visible = Array(lines.prefix(ReleaseNotesPreview.maxLines))
        var preview = visible.joined(separator: "\n")
        var wasTrimmed = hadMoreLines

        if preview.count > ReleaseNotesPreview.maxCharacters {
            let cutoff = preview.index(preview.startIndex, offsetBy: ReleaseNotesPreview.maxCharacters)
            preview = String(preview[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines)
            wasTrimmed = true
        }

        if wasTrimmed, !preview.hasSuffix("…") {
            let maxCharsBeforeEllipsis = max(ReleaseNotesPreview.maxCharacters - 1, 0)
            if preview.count > maxCharsBeforeEllipsis {
                let cutoff = preview.index(preview.startIndex, offsetBy: maxCharsBeforeEllipsis)
                preview = String(preview[..<cutoff]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            preview += "…"
        }

        return preview.isEmpty ? nil : preview
    }

    private func sanitizeReleaseLine(_ line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        while cleaned.hasPrefix("#") {
            cleaned.removeFirst()
            cleaned = cleaned.trimmingCharacters(in: .whitespaces)
        }
        cleaned = cleaned
            .replacingOccurrences(of: "**", with: "")
            .replacingOccurrences(of: "__", with: "")
            .replacingOccurrences(of: "`", with: "")
            .replacingOccurrences(of: #"^\s*([-*+]|\d+\.)\s+"#, with: "", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// For testing: clears the update prompt cooldown.
    @MainActor
    static func resetLastShown() {
        AppUpdateService.shared.autoPromptSnoozedUntilInSession = nil
        AppUpdateService.shared.suppressedUpdateIDThisSession = nil
    }
}
