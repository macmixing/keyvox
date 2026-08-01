import Foundation

nonisolated enum AppReviewRequestPolicy {
    private static let eligibilityWindow: TimeInterval = 7 * 24 * 60 * 60

    static func isEligible(
        firstLaunchAt: Date,
        lastSuccessfulDictationAt: Date?,
        lastRequestedVersion: String?,
        currentVersion: String,
        hasCompletedOnboardingBeforeCurrentLaunch: Bool,
        now: Date
    ) -> Bool {
        guard hasCompletedOnboardingBeforeCurrentLaunch else { return false }

        let installationAge = now.timeIntervalSince(firstLaunchAt)
        guard installationAge >= eligibilityWindow else { return false }

        guard let lastSuccessfulDictationAt else { return false }
        let timeSinceSuccessfulDictation = now.timeIntervalSince(lastSuccessfulDictationAt)
        guard timeSinceSuccessfulDictation >= 0,
              timeSinceSuccessfulDictation <= eligibilityWindow else {
            return false
        }

        return lastRequestedVersion != currentVersion
    }
}
