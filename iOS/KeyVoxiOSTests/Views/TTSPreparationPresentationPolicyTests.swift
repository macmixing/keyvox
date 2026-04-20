import Testing
@testable import KeyVox_iOS

struct TTSPreparationPresentationPolicyTests {
    @Test func warmStartShowsProgressWithoutSpinnerBeforeProgressThreshold() {
        #expect(
            TTSPreparationPresentationPolicy.showsProgress(
                state: .preparing,
                progress: 0,
                visibleThreshold: 0.02,
                isWarmStart: true
            )
        )
        #expect(
            TTSPreparationPresentationPolicy.showsSpinner(
                state: .preparing,
                progress: 0,
                visibleThreshold: 0.02,
                isWarmStart: true
            ) == false
        )
    }

    @Test func coldStartShowsSpinnerUntilProgressReachesThreshold() {
        #expect(
            TTSPreparationPresentationPolicy.showsProgress(
                state: .generating,
                progress: 0,
                visibleThreshold: 0.02,
                isWarmStart: false
            ) == false
        )
        #expect(
            TTSPreparationPresentationPolicy.showsSpinner(
                state: .generating,
                progress: 0,
                visibleThreshold: 0.02,
                isWarmStart: false
            )
        )
    }
}
