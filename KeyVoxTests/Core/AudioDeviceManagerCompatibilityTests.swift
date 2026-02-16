import XCTest
@testable import KeyVox

final class AudioDeviceManagerCompatibilityTests: XCTestCase {
    func testCaptureDeviceNotificationNamesMatchMainEquivalentBehavior() {
        XCTAssertEqual(
            AudioDeviceManager.captureDeviceConnectedNotification.rawValue,
            "AVCaptureDeviceWasConnectedNotification"
        )
        XCTAssertEqual(
            AudioDeviceManager.captureDeviceDisconnectedNotification.rawValue,
            "AVCaptureDeviceWasDisconnectedNotification"
        )
        XCTAssertNotEqual(
            AudioDeviceManager.captureDeviceConnectedNotification,
            AudioDeviceManager.captureDeviceDisconnectedNotification
        )
    }
}
