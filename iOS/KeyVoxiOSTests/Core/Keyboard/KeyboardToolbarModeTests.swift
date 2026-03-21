import Testing
@testable import KeyVox_iOS

struct KeyboardToolbarModeTests {
    @Test func activePhoneCallUsesPhoneCallWarning() {
        let mode = KeyboardToolbarMode.resolve(
            isModelInstalled: true,
            hasFullAccess: true,
            hasMicrophonePermission: true,
            hasActivePhoneCall: true
        )

        #expect(mode == .phoneCallWarning)
        #expect(mode.warningText == "Use KeyVox after this call.")
    }

    @Test func activePhoneCallDoesNotOverrideHigherPriorityWarnings() {
        let fullAccessMode = KeyboardToolbarMode.resolve(
            isModelInstalled: true,
            hasFullAccess: false,
            hasMicrophonePermission: true,
            hasActivePhoneCall: true
        )
        let microphoneMode = KeyboardToolbarMode.resolve(
            isModelInstalled: true,
            hasFullAccess: true,
            hasMicrophonePermission: false,
            hasActivePhoneCall: true
        )

        #expect(fullAccessMode == .fullAccessWarning)
        #expect(microphoneMode == .microphoneWarning)
    }
}
