import Testing
@testable import KeyVox_iOS

@MainActor
struct OnboardingKeyboardTourStateTests {
    @Test func sceneProgressesFromAToBToC() {
        #expect(OnboardingKeyboardTourState().scene == .a)

        #expect(
            OnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: true,
                hasCompletedFirstTourTranscription: false
            ).scene == .b
        )

        #expect(
            OnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: true,
                hasCompletedFirstTourTranscription: true
            ).scene == .c
        )
    }

    @Test func finishRequiresKeyboardShownAndFirstTranscription() {
        #expect(OnboardingKeyboardTourState().canFinish == false)

        #expect(
            OnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: true,
                hasCompletedFirstTourTranscription: false
            ).canFinish == false
        )

        #expect(
            OnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: false,
                hasCompletedFirstTourTranscription: true
            ).canFinish == false
        )

        #expect(
            OnboardingKeyboardTourState(
                hasShownKeyVoxKeyboard: true,
                hasCompletedFirstTourTranscription: true
            ).canFinish
        )
    }
}
