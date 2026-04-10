import Foundation
import Testing
@testable import KeyVox_iOS

struct AppUpdatePolicyEvaluatorTests {
    @Test func returnsNoDecisionWhenCurrentVersionMatchesLatestRelease() throws {
        let currentVersion = try #require(AppVersion("1.0.1"))
        let latestRelease = AppStoreRelease(
            version: try #require(AppVersion("1.0.1")),
            storeURL: try #require(URL(string: "https://apps.apple.com/app/id6760396964"))
        )

        let decision = AppUpdatePolicyEvaluator.decision(
            currentVersion: currentVersion,
            release: latestRelease,
            policy: AppUpdatePolicy(minimumSupportedVersion: try #require(AppVersion("1.0.1")))
        )

        #expect(decision == nil)
    }

    @Test func returnsOptionalDecisionWhenCurrentVersionIsBelowLatestButAboveMinimumSupported() throws {
        let currentVersion = try #require(AppVersion("1.0.1"))
        let latestRelease = AppStoreRelease(
            version: try #require(AppVersion("1.0.2")),
            storeURL: try #require(URL(string: "https://apps.apple.com/app/id6760396964"))
        )
        let policy = AppUpdatePolicy(minimumSupportedVersion: try #require(AppVersion("1.0.1")))

        let decision = try #require(
            AppUpdatePolicyEvaluator.decision(
                currentVersion: currentVersion,
                release: latestRelease,
                policy: policy
            )
        )

        #expect(decision.urgency == .optional)
    }

    @Test func returnsForcedDecisionWhenCurrentVersionIsBelowMinimumSupported() throws {
        let currentVersion = try #require(AppVersion("1.0.0"))
        let latestRelease = AppStoreRelease(
            version: try #require(AppVersion("1.0.2")),
            storeURL: try #require(URL(string: "https://apps.apple.com/app/id6760396964"))
        )
        let policy = AppUpdatePolicy(minimumSupportedVersion: try #require(AppVersion("1.0.1")))

        let decision = try #require(
            AppUpdatePolicyEvaluator.decision(
                currentVersion: currentVersion,
                release: latestRelease,
                policy: policy
            )
        )

        #expect(decision.urgency == .forced)
    }
}
