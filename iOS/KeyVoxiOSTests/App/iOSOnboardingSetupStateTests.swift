import Testing
@testable import KeyVox_iOS

struct iOSOnboardingSetupStateTests {
    @Test func continueRequiresAllThreeRequirements() {
        #expect(
            iOSOnboardingSetupState(
                isModelReady: false,
                isMicrophonePermissionGranted: true,
                isKeyboardAccessConfirmed: true
            ).canContinue == false
        )

        #expect(
            iOSOnboardingSetupState(
                isModelReady: true,
                isMicrophonePermissionGranted: false,
                isKeyboardAccessConfirmed: true
            ).canContinue == false
        )

        #expect(
            iOSOnboardingSetupState(
                isModelReady: true,
                isMicrophonePermissionGranted: true,
                isKeyboardAccessConfirmed: false
            ).canContinue == false
        )

        #expect(
            iOSOnboardingSetupState(
                isModelReady: true,
                isMicrophonePermissionGranted: true,
                isKeyboardAccessConfirmed: true
            ).canContinue
        )
    }
}
