import Testing
@testable import KeyVox_iOS

struct KeyboardToolbarModeTests {
    @Test func readyConfigurationUsesBrandedToolbar() {
        let mode = KeyboardToolbarMode.resolve(
            modelAvailability: .ready,
            hasFullAccess: true,
            hasMicrophonePermission: true
        )

        #expect(mode == .branded)
        #expect(mode.warningText == nil)
    }

    @Test func accessWarningsRemainAvailable() {
        let fullAccessMode = KeyboardToolbarMode.resolve(
            modelAvailability: .ready,
            hasFullAccess: false,
            hasMicrophonePermission: true
        )
        let microphoneMode = KeyboardToolbarMode.resolve(
            modelAvailability: .ready,
            hasFullAccess: true,
            hasMicrophonePermission: false
        )

        #expect(fullAccessMode == .fullAccessWarning)
        #expect(microphoneMode == .microphoneWarning)
    }
}
