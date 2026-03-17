import Testing
@testable import KeyVox_iOS

@MainActor
struct OnboardingMicrophonePermissionControllerTests {
    @Test func requestPermissionRefreshesGrantedStateFromProvider() async {
        var status = OnboardingMicrophonePermissionStatus.undetermined
        let controller = OnboardingMicrophonePermissionController(
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
        let status = OnboardingMicrophonePermissionStatus.denied
        let controller = OnboardingMicrophonePermissionController(
            statusProvider: { status },
            requestPermissionHandler: { false }
        )

        await controller.requestPermission()

        #expect(controller.status == .denied)
    }
}
