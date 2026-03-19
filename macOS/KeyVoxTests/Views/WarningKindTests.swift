import Foundation
import XCTest
@testable import KeyVox

final class WarningKindTests: XCTestCase {
    func testNoSpeechVariantUsesRequestedTitleAndMessage() {
        let kind = WarningKind.microphoneSilence(
            reason: .noSpeechDetected,
            microphoneName: "Built-in Microphone"
        )

        XCTAssertTrue(kind.title == "Didn't hear that!")
        XCTAssertTrue(
            kind.message == "KeyVox didn't pick up any speech from your Built-in Microphone microphone."
        )
    }

    func testMutedVariantIncludesHardwareNameInMessage() {
        let kind = WarningKind.microphoneSilence(
            reason: .muted,
            microphoneName: "MacBook Pro Microphone"
        )

        XCTAssertTrue(
            kind.message == "Your MacBook Pro Microphone mic may be muted. Check System Settings or switch the input device in KeyVox Settings."
        )
    }

    func testMicrophoneSilenceVariantsKeepSameActions() {
        let muted = WarningKind.microphoneSilence(reason: .muted, microphoneName: "Mic A")
        let noSpeech = WarningKind.microphoneSilence(reason: .noSpeechDetected, microphoneName: "Mic B")

        XCTAssertTrue(muted.settingsTab == .audio)
        XCTAssertTrue(noSpeech.settingsTab == .audio)
        XCTAssertTrue(muted.showsKeyVoxSettingsButton)
        XCTAssertTrue(noSpeech.showsKeyVoxSettingsButton)
        XCTAssertTrue(muted.systemSettingsURL != nil)
        XCTAssertTrue(noSpeech.systemSettingsURL != nil)
    }

    func testBlankMicrophoneNameFallsBackToCurrentDevice() {
        let kind = WarningKind.microphoneSilence(reason: .muted, microphoneName: "   ")
        XCTAssertTrue(
            kind.message == "Your current device mic may be muted. Check System Settings or switch the input device in KeyVox Settings."
        )
    }
}
