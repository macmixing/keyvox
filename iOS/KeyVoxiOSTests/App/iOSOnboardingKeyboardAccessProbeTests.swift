import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct iOSOnboardingKeyboardAccessProbeTests {
    @Test func missingKeyboardMarkerKeepsProbeIncomplete() {
        let probe = iOSOnboardingKeyboardAccessProbe(
            timestampProvider: { nil },
            presentationTimestampProvider: { nil },
            enabledProvider: { false },
            fullAccessProvider: { false }
        )

        #expect(probe.hasConfirmedKeyboardAccess == false)
        #expect(probe.hasShownKeyVoxKeyboard == false)
        #expect(probe.isKeyboardEnabledInSystemSettings == false)
        #expect(probe.lastKeyboardPresentationTimestamp == nil)
        #expect(probe.hasFullAccessConfirmedByKeyboard == false)
        #expect(probe.lastConfirmedAccessTimestamp == nil)
    }

    @Test func validKeyboardMarkerMarksProbeComplete() {
        let probe = iOSOnboardingKeyboardAccessProbe(
            timestampProvider: { 123 },
            presentationTimestampProvider: { 456 },
            enabledProvider: { true },
            fullAccessProvider: { true }
        )

        #expect(probe.hasConfirmedKeyboardAccess)
        #expect(probe.hasShownKeyVoxKeyboard)
        #expect(probe.isKeyboardEnabledInSystemSettings)
        #expect(probe.lastKeyboardPresentationTimestamp == 456)
        #expect(probe.hasFullAccessConfirmedByKeyboard)
        #expect(probe.lastConfirmedAccessTimestamp == 123)
    }

    @Test func invalidKeyboardMarkerIsRejectedOnRefresh() {
        let state = TimestampState(value: 123)
        let presentationState = TimestampState(value: 456)
        let probe = iOSOnboardingKeyboardAccessProbe(
            timestampProvider: { state.value },
            presentationTimestampProvider: { presentationState.value },
            enabledProvider: { true },
            fullAccessProvider: { false }
        )

        state.value = 0
        presentationState.value = 0
        probe.refresh()

        #expect(probe.hasConfirmedKeyboardAccess == false)
        #expect(probe.hasShownKeyVoxKeyboard == false)
        #expect(probe.isKeyboardEnabledInSystemSettings)
        #expect(probe.lastKeyboardPresentationTimestamp == nil)
        #expect(probe.hasFullAccessConfirmedByKeyboard == false)
        #expect(probe.lastConfirmedAccessTimestamp == nil)
    }
}

@MainActor
private final class TimestampState {
    var value: TimeInterval?

    init(value: TimeInterval?) {
        self.value = value
    }
}
