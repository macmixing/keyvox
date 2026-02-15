import Foundation
import Testing
@testable import KeyVox

struct WarningKindTests {
    @Test
    func noSpeechVariantUsesRequestedTitleAndMessage() {
        let kind = WarningKind.microphoneSilence(
            reason: .noSpeechDetected,
            microphoneName: "Built-in Microphone"
        )

        #expect(kind.title == "Didn't hear that!")
        #expect(
            kind.message == "KeyVox didn't pick up any speech from your Built-in Microphone microphone."
        )
    }

    @Test
    func mutedVariantIncludesHardwareNameInMessage() {
        let kind = WarningKind.microphoneSilence(
            reason: .muted,
            microphoneName: "MacBook Pro Microphone"
        )

        #expect(
            kind.message == "Your MacBook Pro Microphone mic may be muted. Check System Settings or switch the input device in KeyVox Settings."
        )
    }

    @Test
    func microphoneSilenceVariantsKeepSameActions() {
        let muted = WarningKind.microphoneSilence(reason: .muted, microphoneName: "Mic A")
        let noSpeech = WarningKind.microphoneSilence(reason: .noSpeechDetected, microphoneName: "Mic B")

        #expect(muted.settingsTab == .audio)
        #expect(noSpeech.settingsTab == .audio)
        #expect(muted.showsKeyVoxSettingsButton)
        #expect(noSpeech.showsKeyVoxSettingsButton)
        #expect(muted.systemSettingsURL != nil)
        #expect(noSpeech.systemSettingsURL != nil)
    }

    @Test
    func blankMicrophoneNameFallsBackToCurrentDevice() {
        let kind = WarningKind.microphoneSilence(reason: .muted, microphoneName: "   ")
        #expect(
            kind.message == "Your current device mic may be muted. Check System Settings or switch the input device in KeyVox Settings."
        )
    }
}
