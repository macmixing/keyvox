import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSOnboardingMicrophonePermissionControllerTests {
    @Test func requestPermissionRefreshesGrantedStateFromProvider() async {
        var status = iOSOnboardingMicrophonePermissionStatus.undetermined
        let controller = iOSOnboardingMicrophonePermissionController(
            statusProvider: { status },
            requestPermissionHandler: {
                status = .granted
                return true
            }
        )

        await controller.requestPermission()

        #expect(controller.status == .granted)
    }

    @Test func requestPermissionKeepsDeniedStateWhenAccessIsNotGranted() async {
        let status = iOSOnboardingMicrophonePermissionStatus.denied
        let controller = iOSOnboardingMicrophonePermissionController(
            statusProvider: { status },
            requestPermissionHandler: { false }
        )

        await controller.requestPermission()

        #expect(controller.status == .denied)
    }
}
