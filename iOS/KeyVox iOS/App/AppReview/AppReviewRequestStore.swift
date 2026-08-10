import Foundation

@MainActor
final class AppReviewRequestStore {
    private let defaults: UserDefaults
    private let now: () -> Date

    init(
        defaults: UserDefaults,
        now: @escaping () -> Date = Date.init
    ) {
        self.defaults = defaults
        self.now = now

        if defaults.object(forKey: UserDefaultsKeys.App.reviewFirstLaunchAt) == nil {
            defaults.set(now(), forKey: UserDefaultsKeys.App.reviewFirstLaunchAt)
        }
    }

    func recordSuccessfulDictation() {
        defaults.set(now(), forKey: UserDefaultsKeys.App.reviewLastSuccessfulDictationAt)
    }

    func isEligible(
        currentVersion: String,
        hasCompletedOnboardingBeforeCurrentLaunch: Bool
    ) -> Bool {
        guard let firstLaunchAt = defaults.object(
            forKey: UserDefaultsKeys.App.reviewFirstLaunchAt
        ) as? Date else {
            return false
        }

        return AppReviewRequestPolicy.isEligible(
            firstLaunchAt: firstLaunchAt,
            lastSuccessfulDictationAt: defaults.object(
                forKey: UserDefaultsKeys.App.reviewLastSuccessfulDictationAt
            ) as? Date,
            lastRequestedVersion: defaults.string(
                forKey: UserDefaultsKeys.App.reviewLastRequestedVersion
            ),
            currentVersion: currentVersion,
            hasCompletedOnboardingBeforeCurrentLaunch: hasCompletedOnboardingBeforeCurrentLaunch,
            now: now()
        )
    }

    func markRequested(for version: String) {
        defaults.set(version, forKey: UserDefaultsKeys.App.reviewLastRequestedVersion)
    }
}
