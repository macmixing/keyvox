import Testing
@testable import KeyVox_iOS

struct OnboardingSetupStateTests {
    @Test func continueRequiresAllThreeRequirements() {
        #expect(
            OnboardingSetupState(
                isModelReady: false,
                isMicrophonePermissionGranted: true,
                isKeyboardAccessConfirmed: true
            ).canContinue == false
        )

        #expect(
            OnboardingSetupState(
                isModelReady: true,
                isMicrophonePermissionGranted: false,
                isKeyboardAccessConfirmed: true
            ).canContinue == false
        )

        #expect(
            OnboardingSetupState(
                isModelReady: true,
                isMicrophonePermissionGranted: true,
                isKeyboardAccessConfirmed: false
            ).canContinue == false
        )

        #expect(
            OnboardingSetupState(
                isModelReady: true,
                isMicrophonePermissionGranted: true,
                isKeyboardAccessConfirmed: true
            ).canContinue
        )
    }
}
