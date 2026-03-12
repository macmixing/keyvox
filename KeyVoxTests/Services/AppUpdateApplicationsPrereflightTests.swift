import Foundation
import XCTest
@testable import KeyVox

final class AppUpdateApplicationsPrereflightTests: XCTestCase {
    func testRequiresApplicationsInstallForNonApplicationsPath() {
        let service = AppUpdateApplicationsPrereflight()
        let bundleURL = URL(fileURLWithPath: "/Users/test/Downloads/KeyVox.app", isDirectory: true)
        XCTAssertTrue(service.requiresApplicationsInstall(bundleURL: bundleURL))
    }

    func testDestinationURLUsesApplicationsFolder() {
        let service = AppUpdateApplicationsPrereflight()
        let bundleURL = URL(fileURLWithPath: "/Users/test/Desktop/KeyVox.app", isDirectory: true)
        XCTAssertEqual(service.destinationURL(for: bundleURL).path, "/Applications/KeyVox.app")
    }

    func testConsumeResumeAfterApplicationsMoveClearsFlag() {
        let defaults = UserDefaults(suiteName: #function)!
        defaults.removePersistentDomain(forName: #function)
        defer {
            defaults.removePersistentDomain(forName: #function)
        }

        let service = AppUpdateApplicationsPrereflight(defaults: defaults)
        service.stageResumeAfterApplicationsMove()

        XCTAssertTrue(service.consumeResumeAfterApplicationsMove())
        XCTAssertFalse(service.consumeResumeAfterApplicationsMove())
    }
}
