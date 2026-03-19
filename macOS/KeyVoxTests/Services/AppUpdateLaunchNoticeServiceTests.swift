import Foundation
import XCTest
@testable import KeyVox

final class AppUpdateLaunchNoticeServiceTests: XCTestCase {
    func testConsumePendingNoticeReturnsVersionWhenCurrentVersionMatches() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let bundle = Bundle.main
        let currentVersion = AppUpdateLogic.normalizeVersionTag(
            (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        )
        let service = AppUpdateLaunchNoticeService(bundle: bundle, defaults: defaults)
        service.stagePendingUpdatedVersion(currentVersion)

        XCTAssertEqual(service.consumePendingNoticeVersionIfNeeded(), currentVersion)
    }

    func testConsumePendingNoticeClearsMismatchedVersion() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let service = AppUpdateLaunchNoticeService(bundle: .main, defaults: defaults)
        service.stagePendingUpdatedVersion("999.0.0")

        XCTAssertNil(service.consumePendingNoticeVersionIfNeeded())
        XCTAssertNil(defaults.string(forKey: UserDefaultsKeys.App.pendingUpdatedVersion))
    }

    func testStagePendingUpdatedVersionClearsAcknowledgedVersionForRepeatUpdate() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let bundle = Bundle.main
        let currentVersion = AppUpdateLogic.normalizeVersionTag(
            (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        )
        let service = AppUpdateLaunchNoticeService(bundle: bundle, defaults: defaults)

        service.acknowledge(version: currentVersion)
        service.stagePendingUpdatedVersion(currentVersion)

        XCTAssertEqual(service.consumePendingNoticeVersionIfNeeded(), currentVersion)
    }

    func testConsumePendingNoticeNormalizesPendingVersionBeforeComparing() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let bundle = Bundle.main
        let currentVersion = AppUpdateLogic.normalizeVersionTag(
            (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        )
        let service = AppUpdateLaunchNoticeService(bundle: bundle, defaults: defaults)
        defaults.set("v\(currentVersion)", forKey: UserDefaultsKeys.App.pendingUpdatedVersion)

        XCTAssertEqual(service.consumePendingNoticeVersionIfNeeded(), currentVersion)
    }
}
