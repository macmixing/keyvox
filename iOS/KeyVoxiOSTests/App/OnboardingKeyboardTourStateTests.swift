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

    @Test func sceneTruthTableLocksCurrentKeyboardTourStateMachine() {
        let cases: [(OnboardingKeyboardTourState, OnboardingKeyboardTourState.Scene)] = [
            (
                OnboardingKeyboardTourState(
                    hasShownKeyVoxKeyboard: false,
                    hasCompletedFirstTourTranscription: false
                ),
                .a
            ),
            (
                OnboardingKeyboardTourState(
                    hasShownKeyVoxKeyboard: true,
                    hasCompletedFirstTourTranscription: false
                ),
                .b
            ),
            (
                OnboardingKeyboardTourState(
                    hasShownKeyVoxKeyboard: false,
                    hasCompletedFirstTourTranscription: true
                ),
                .a
            ),
            (
                OnboardingKeyboardTourState(
                    hasShownKeyVoxKeyboard: true,
                    hasCompletedFirstTourTranscription: true
                ),
                .c
            )
        ]

        for (state, expectedScene) in cases {
            #expect(state.scene == expectedScene)
        }
    }

    @Test func transcriptionCompletionWithoutKeyboardShownFallsBackToSceneAAndCannotFinish() {
        let state = OnboardingKeyboardTourState(
            hasShownKeyVoxKeyboard: false,
            hasCompletedFirstTourTranscription: true
        )

        #expect(state.scene == .a)
        #expect(state.canFinish == false)
    }

    @Test func keyboardShownWithoutTourTranscriptionStaysOnSceneBAndCannotFinish() {
        let state = OnboardingKeyboardTourState(
            hasShownKeyVoxKeyboard: true,
            hasCompletedFirstTourTranscription: false
        )

        #expect(state.scene == .b)
        #expect(state.canFinish == false)
    }

    @Test func pristineTourStateStartsOnSceneAAndCannotFinish() {
        let state = OnboardingKeyboardTourState()

        #expect(state.scene == .a)
        #expect(state.canFinish == false)
    }

    @Test func fullyCompletedTourStateEndsOnSceneCAndCanFinish() {
        let state = OnboardingKeyboardTourState(
            hasShownKeyVoxKeyboard: true,
            hasCompletedFirstTourTranscription: true
        )

        #expect(state.scene == .c)
        #expect(state.canFinish)
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
