import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSOnboardingKeyboardTourStateTests {
    @Test func sceneProgressesFromAToBToC() {
        #expect(iOSOnboardingKeyboardTourState().scene == .a)

        #expect(
            iOSOnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: true,
                hasCompletedFirstTourTranscription: false
            ).scene == .b
        )

        #expect(
            iOSOnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: true,
                hasCompletedFirstTourTranscription: true
            ).scene == .c
        )
    }

    @Test func finishRequiresKeyboardShownAndFirstTranscription() {
        #expect(iOSOnboardingKeyboardTourState().canFinish == false)

        #expect(
            iOSOnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: true,
                hasCompletedFirstTourTranscription: false
            ).canFinish == false
        )

        #expect(
            iOSOnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: false,
                hasCompletedFirstTourTranscription: true
            ).canFinish == false
        )

        #expect(
            iOSOnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: true,
                hasCompletedFirstTourTranscription: true
            ).canFinish
        )
    }
}
