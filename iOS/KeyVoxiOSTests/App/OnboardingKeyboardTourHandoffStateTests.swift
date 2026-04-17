import Testing
@testable import KeyVox_iOS

struct OnboardingKeyboardTourHandoffStateTests {
    @Test func keyboardTourHandoffRequiresModelMicrophoneAndKeyboardEnablement() {
        #expect(
            OnboardingKeyboardTourHandoffState(
                isModelReady: false,
                isMicrophonePermissionGranted: true,
                isKeyboardEnabledInSystemSettings: true
            ).canStartKeyboardTour == false
        )

        #expect(
            OnboardingKeyboardTourHandoffState(
                isModelReady: true,
                isMicrophonePermissionGranted: false,
                isKeyboardEnabledInSystemSettings: true
            ).canStartKeyboardTour == false
        )

        #expect(
            OnboardingKeyboardTourHandoffState(
                isModelReady: true,
                isMicrophonePermissionGranted: true,
                isKeyboardEnabledInSystemSettings: false
            ).canStartKeyboardTour == false
        )

        #expect(
            OnboardingKeyboardTourHandoffState(
                isModelReady: true,
                isMicrophonePermissionGranted: true,
                isKeyboardEnabledInSystemSettings: true
            ).canStartKeyboardTour
        )
    }
}
