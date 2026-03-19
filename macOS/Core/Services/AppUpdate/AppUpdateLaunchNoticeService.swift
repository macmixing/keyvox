import Foundation

struct AppUpdateLaunchNoticeService {
    private let bundle: Bundle
    private let defaults: UserDefaults

    init(
        bundle: Bundle = .main,
        defaults: UserDefaults = .standard
    ) {
        self.bundle = bundle
        self.defaults = defaults
    }

    func stagePendingUpdatedVersion(_ version: String) {
        defaults.set(version, forKey: UserDefaultsKeys.App.pendingUpdatedVersion)
        defaults.removeObject(forKey: UserDefaultsKeys.App.lastAcknowledgedUpdatedVersion)
    }

    func consumePendingNoticeVersionIfNeeded() -> String? {
        let currentVersion = AppUpdateLogic.normalizeVersionTag(
            (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        )
        guard let pendingVersion = defaults.string(forKey: UserDefaultsKeys.App.pendingUpdatedVersion) else {
            return nil
        }
        let normalizedPendingVersion = AppUpdateLogic.normalizeVersionTag(pendingVersion)

        if normalizedPendingVersion == currentVersion,
           defaults.string(forKey: UserDefaultsKeys.App.lastAcknowledgedUpdatedVersion) != currentVersion {
            return normalizedPendingVersion
        }

        defaults.removeObject(forKey: UserDefaultsKeys.App.pendingUpdatedVersion)
        return nil
    }

    func acknowledge(version: String) {
        defaults.set(version, forKey: UserDefaultsKeys.App.lastAcknowledgedUpdatedVersion)
        defaults.removeObject(forKey: UserDefaultsKeys.App.pendingUpdatedVersion)
    }
}
