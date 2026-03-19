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

    func testContainsRecommendedBuiltInMicrophoneWhenBuiltInExists() {
        let microphones: [MicrophoneOption] = [
            MicrophoneOption(id: "a", name: "External Mic", kind: .wiredOrOther, isAvailable: true),
            MicrophoneOption(id: "b", name: "Built-in Microphone", kind: .builtIn, isAvailable: true)
        ]

        XCTAssertTrue(AudioDeviceManager.containsRecommendedBuiltInMicrophone(microphones))
    }

    func testContainsRecommendedBuiltInMicrophoneFalseWithoutBuiltIn() {
        let microphones: [MicrophoneOption] = [
            MicrophoneOption(id: "a", name: "AirPods Mic", kind: .airPods, isAvailable: true),
            MicrophoneOption(id: "b", name: "USB Mic", kind: .wiredOrOther, isAvailable: true)
        ]

        XCTAssertFalse(AudioDeviceManager.containsRecommendedBuiltInMicrophone(microphones))
    }

    func testContainsRecommendedBuiltInMicrophoneIgnoresUnavailableBuiltIn() {
        let microphones: [MicrophoneOption] = [
            MicrophoneOption(id: "a", name: "Built-in Microphone", kind: .builtIn, isAvailable: false)
        ]

        XCTAssertFalse(AudioDeviceManager.containsRecommendedBuiltInMicrophone(microphones))
    }
}
