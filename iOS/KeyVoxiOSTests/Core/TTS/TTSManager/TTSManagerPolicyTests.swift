import Testing
@testable import KeyVox_iOS

struct TTSManagerPolicyTests {
    @Test func idleSleepPreventionMatchesPlaybackState() {
        #expect(TTSManagerPolicy.shouldPreventIdleSleep(for: .preparing, isPlaybackPaused: false))
        #expect(TTSManagerPolicy.shouldPreventIdleSleep(for: .generating, isPlaybackPaused: false))
        #expect(TTSManagerPolicy.shouldPreventIdleSleep(for: .playing, isPlaybackPaused: false))
        #expect(TTSManagerPolicy.shouldPreventIdleSleep(for: .playing, isPlaybackPaused: true) == false)
        #expect(TTSManagerPolicy.shouldPreventIdleSleep(for: .idle, isPlaybackPaused: false) == false)
        #expect(TTSManagerPolicy.shouldPreventIdleSleep(for: .finished, isPlaybackPaused: false) == false)
        #expect(TTSManagerPolicy.shouldPreventIdleSleep(for: .error, isPlaybackPaused: false) == false)
    }

    @Test func activeStateMatchesTtsLifecycle() {
        #expect(TTSManagerPolicy.isActive(.preparing))
        #expect(TTSManagerPolicy.isActive(.generating))
        #expect(TTSManagerPolicy.isActive(.playing))
        #expect(TTSManagerPolicy.isActive(.idle) == false)
        #expect(TTSManagerPolicy.isActive(.finished) == false)
        #expect(TTSManagerPolicy.isActive(.error) == false)
    }

    @Test func fastModeKeyboardRequestsSuppressPreparationView() {
        #expect(
            TTSManagerPolicy.shouldShowPreparationView(
                requested: true,
                fastModeEnabled: true,
                sourceSurface: .keyboard
            ) == false
        )
        #expect(
            TTSManagerPolicy.shouldShowPreparationView(
                requested: true,
                fastModeEnabled: true,
                sourceSurface: .app
            )
        )
        #expect(
            TTSManagerPolicy.shouldShowPreparationView(
                requested: true,
                fastModeEnabled: false,
                sourceSurface: .keyboard
            )
        )
        #expect(
            TTSManagerPolicy.shouldShowPreparationView(
                requested: false,
                fastModeEnabled: false,
                sourceSurface: .app
            ) == false
        )
    }

    @Test func backgroundTaskPolicyRespectsModeAndForce() {
        #expect(
            TTSManagerPolicy.shouldBeginBackgroundTask(
                isActive: true,
                fastModeEnabled: false,
                force: false
            )
        )
        #expect(
            TTSManagerPolicy.shouldBeginBackgroundTask(
                isActive: true,
                fastModeEnabled: true,
                force: false
            ) == false
        )
        #expect(
            TTSManagerPolicy.shouldBeginBackgroundTask(
                isActive: true,
                fastModeEnabled: true,
                force: true
            )
        )
        #expect(
            TTSManagerPolicy.shouldBeginBackgroundTask(
                isActive: false,
                fastModeEnabled: false,
                force: true
            ) == false
        )
    }
}
