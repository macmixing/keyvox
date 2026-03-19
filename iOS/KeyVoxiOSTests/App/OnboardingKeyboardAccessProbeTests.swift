import Foundation
import Testing
@testable import KeyVox_iOS

@MainActor
struct OnboardingKeyboardAccessProbeTests {
    @Test func missingKeyboardMarkerKeepsProbeIncomplete() {
        let probe = OnboardingKeyboardAccessProbe(
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
        let probe = OnboardingKeyboardAccessProbe(
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

    @Test func fullAccessWithoutConfirmationTimestampRemainsIntermediateState() {
        let probe = OnboardingKeyboardAccessProbe(
            timestampProvider: { nil },
            presentationTimestampProvider: { 456 },
            enabledProvider: { true },
            fullAccessProvider: { true }
        )

        #expect(probe.hasConfirmedKeyboardAccess == false)
        #expect(probe.hasShownKeyVoxKeyboard)
        #expect(probe.isKeyboardEnabledInSystemSettings)
        #expect(probe.lastKeyboardPresentationTimestamp == 456)
        #expect(probe.hasFullAccessConfirmedByKeyboard)
        #expect(probe.lastConfirmedAccessTimestamp == nil)
    }

    @Test func invalidKeyboardMarkerIsRejectedOnRefresh() {
        let state = TimestampState(value: 123)
        let presentationState = TimestampState(value: 456)
        let probe = OnboardingKeyboardAccessProbe(
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
