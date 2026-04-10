import Testing
@testable import KeyVox_iOS

struct KeyboardToolbarModeTests {
    @Test func activePhoneCallUsesPhoneCallWarning() {
        let mode = KeyboardToolbarMode.resolve(
            isModelInstalled: true,
            hasFullAccess: true,
            hasMicrophonePermission: true,
            hasActivePhoneCall: true,
            isUpdateRequired: false
        )

        #expect(mode == .phoneCallWarning)
        #expect(mode.warningText != nil)
        #expect(mode.showsWarningInfoButton == false)
    }

    @Test func activePhoneCallDoesNotOverrideHigherPriorityWarnings() {
        let fullAccessMode = KeyboardToolbarMode.resolve(
            isModelInstalled: true,
            hasFullAccess: false,
            hasMicrophonePermission: true,
            hasActivePhoneCall: true,
            isUpdateRequired: false
        )
        let microphoneMode = KeyboardToolbarMode.resolve(
            isModelInstalled: true,
            hasFullAccess: true,
            hasMicrophonePermission: false,
            hasActivePhoneCall: true,
            isUpdateRequired: false
        )

        #expect(fullAccessMode == .fullAccessWarning)
        #expect(microphoneMode == .microphoneWarning)
    }
}
