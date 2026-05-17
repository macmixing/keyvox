import XCTest
@testable import KeyVox

@MainActor
final class KeyVoxAppActivationPolicyTests: XCTestCase {
    func testAccessoryPolicyDisabledForSequoiaAndNewer() {
        XCTAssertFalse(
            KeyVoxApp.shouldUseAccessoryActivationPolicy(
                osVersion: OperatingSystemVersion(majorVersion: 15, minorVersion: 6, patchVersion: 0)
            )
        )
        XCTAssertFalse(
            KeyVoxApp.shouldUseAccessoryActivationPolicy(
                osVersion: OperatingSystemVersion(majorVersion: 15, minorVersion: 7, patchVersion: 0)
            )
        )
        XCTAssertFalse(
            KeyVoxApp.shouldUseAccessoryActivationPolicy(
                osVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 0)
            )
        )
    }

    func testAccessoryPolicyEnabledForVenturaAndOlderSonomaBuilds() {
        XCTAssertTrue(
            KeyVoxApp.shouldUseAccessoryActivationPolicy(
                osVersion: OperatingSystemVersion(majorVersion: 13, minorVersion: 7, patchVersion: 3)
            )
        )
        XCTAssertTrue(
            KeyVoxApp.shouldUseAccessoryActivationPolicy(
                osVersion: OperatingSystemVersion(majorVersion: 14, minorVersion: 7, patchVersion: 0)
            )
        )
        XCTAssertTrue(
            KeyVoxApp.shouldUseAccessoryActivationPolicy(
                osVersion: OperatingSystemVersion(majorVersion: 15, minorVersion: 5, patchVersion: 0)
            )
        )
    }

    func testDockIconPreferenceUsesAccessoryPolicyOnlyWhenNoManagedWindowsAreVisible() {
        let controller = DockIconVisibilityController(
            osVersion: OperatingSystemVersion(majorVersion: 16, minorVersion: 0, patchVersion: 0)
        )

        XCTAssertEqual(
            controller.resolvedActivationPolicy(
                hidesDockIconPreference: true,
                hasVisibleManagedWindow: false
            ),
            .accessory
        )
        XCTAssertEqual(
            controller.resolvedActivationPolicy(
                hidesDockIconPreference: true,
                hasVisibleManagedWindow: true
            ),
            .regular
        )
        XCTAssertEqual(
            controller.resolvedActivationPolicy(
                hidesDockIconPreference: false,
                hasVisibleManagedWindow: false
            ),
            .regular
        )
    }

    func testLegacyAccessoryPolicyOverridesDockIconPreference() {
        let controller = DockIconVisibilityController(
            osVersion: OperatingSystemVersion(majorVersion: 15, minorVersion: 5, patchVersion: 0)
        )

        XCTAssertEqual(
            controller.resolvedActivationPolicy(
                hidesDockIconPreference: false,
                hasVisibleManagedWindow: true
            ),
            .accessory
        )
    }
}
