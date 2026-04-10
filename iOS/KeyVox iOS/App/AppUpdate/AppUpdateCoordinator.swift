import Combine
import Foundation
import UIKit

@MainActor
final class AppUpdateCoordinator: ObservableObject {
    struct Prompt: Equatable, Identifiable {
        let decision: AppUpdateDecision

        var id: String {
            "\(decision.release.version.rawValue)-\(decision.urgency)"
        }
    }

    @Published var activePrompt: Prompt?

    private let service: AppUpdateService
    private let defaults: UserDefaults
    private let bundle: Bundle
    private let nowProvider: () -> Date
    private var hasPresentedOptionalPromptThisLaunch = false
    private var refreshTask: Task<Void, Never>?

    init(
        service: AppUpdateService = AppUpdateService(),
        defaults: UserDefaults,
        bundle: Bundle = .main,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.service = service
        self.defaults = defaults
        self.bundle = bundle
        self.nowProvider = nowProvider
    }

    func handleAppDidBecomeActive() {
        restoreCachedPromptIfNeeded()

        guard refreshTask == nil else { return }
        guard shouldRefresh else { return }

        refreshTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.refreshPromptState()
            self.refreshTask = nil
        }
    }

    func dismissOptionalPrompt() {
        guard let prompt = activePrompt else { return }
        guard prompt.decision.urgency == .optional else { return }

        hasPresentedOptionalPromptThisLaunch = true
        activePrompt = nil
    }

    func openAppStore() {
        let storeURL = activePrompt?.decision.release.storeURL ?? cachedDecision?.release.storeURL
        guard let storeURL else { return }

        UIApplication.shared.open(storeURL)
        if activePrompt?.decision.urgency == .optional {
            hasPresentedOptionalPromptThisLaunch = true
            activePrompt = nil
        }
    }

    private func refreshPromptState() async {
        guard let currentVersion = currentAppVersion else { return }

        async let latestReleaseTask = service.fetchLatestRelease()
        async let policyTask = try? service.fetchPolicy()

        guard let latestRelease = try? await latestReleaseTask else {
            return
        }

        let policy = await policyTask
        defaults.set(
            nowProvider().timeIntervalSince1970,
            forKey: UserDefaultsKeys.App.lastAppUpdateCheckTime
        )

        guard let decision = AppUpdatePolicyEvaluator.decision(
            currentVersion: currentVersion,
            release: latestRelease,
            policy: policy
        ) else {
            clearCachedDecision()
            syncPresentationState()
            return
        }

        cache(decision: decision)
        syncPresentationState()
    }

    private var currentAppVersion: AppVersion? {
        guard let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String else {
            return nil
        }

        return AppVersion(version)
    }

    private var shouldRefresh: Bool {
        guard cachedDecision != nil else { return true }

        let lastCheckTime = defaults.double(forKey: UserDefaultsKeys.App.lastAppUpdateCheckTime)
        guard lastCheckTime > 0 else { return true }

        return nowProvider().timeIntervalSince1970 - lastCheckTime >= AppUpdateConfiguration.refreshInterval
    }

    private func restoreCachedPromptIfNeeded() {
        syncPresentationState()
    }

    private func syncPresentationState() {
        guard let currentVersion = currentAppVersion else {
            KeyVoxIPCBridge.setAppUpdateRequired(false)
            activePrompt = nil
            return
        }

        guard let cachedDecision else {
            KeyVoxIPCBridge.setAppUpdateRequired(false)
            activePrompt = nil
            return
        }

        guard currentVersion < cachedDecision.release.version else {
            clearCachedDecision()
            KeyVoxIPCBridge.setAppUpdateRequired(false)
            activePrompt = nil
            return
        }

        KeyVoxIPCBridge.setAppUpdateRequired(cachedDecision.urgency == .forced)

        if cachedDecision.urgency == .forced {
            activePrompt = Prompt(decision: cachedDecision)
            return
        }

        guard hasPresentedOptionalPromptThisLaunch == false else {
            activePrompt = nil
            return
        }

        activePrompt = Prompt(decision: cachedDecision)
    }

    private var cachedDecision: AppUpdateDecision? {
        guard let versionRawValue = defaults.string(forKey: UserDefaultsKeys.App.cachedAppStoreReleaseVersion),
              let version = AppVersion(versionRawValue),
              let urgencyRawValue = defaults.string(forKey: UserDefaultsKeys.App.cachedAppUpdateUrgency),
              let urgency = AppUpdateUrgency(rawValue: urgencyRawValue) else {
            return nil
        }

        let storeURL = defaults.string(forKey: UserDefaultsKeys.App.cachedAppStoreReleaseURL)
            .flatMap(URL.init(string:))
            ?? AppUpdateConfiguration.fallbackAppStoreURL

        return AppUpdateDecision(
            release: AppStoreRelease(version: version, storeURL: storeURL),
            urgency: urgency
        )
    }

    private func cache(decision: AppUpdateDecision) {
        defaults.set(
            decision.release.version.rawValue,
            forKey: UserDefaultsKeys.App.cachedAppStoreReleaseVersion
        )
        defaults.set(
            decision.release.storeURL.absoluteString,
            forKey: UserDefaultsKeys.App.cachedAppStoreReleaseURL
        )
        defaults.set(
            decision.urgency.rawValue,
            forKey: UserDefaultsKeys.App.cachedAppUpdateUrgency
        )
    }

    private func clearCachedDecision() {
        defaults.removeObject(forKey: UserDefaultsKeys.App.cachedAppStoreReleaseVersion)
        defaults.removeObject(forKey: UserDefaultsKeys.App.cachedAppStoreReleaseURL)
        defaults.removeObject(forKey: UserDefaultsKeys.App.cachedAppUpdateUrgency)
    }
}
