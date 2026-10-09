import Foundation

/// The downloaded models the keyboard's toolbar depends on: whether dictation can run and
/// whether a speech voice is ready. Finding out takes dozens of disk lookups, and models are
/// only added or removed in the KeyVox app, so the keyboard checks when it comes on screen and
/// reuses the answer for every update until it comes on screen again.
struct KeyboardInstalledModels {
    let dictation: KeyboardDictationModelStatus.Availability
    let isTTSReady: Bool

    static func check() -> KeyboardInstalledModels {
        let preferredTTSVoiceID = UserDefaults(suiteName: KeyVoxIPCBridge.appGroupID)?
            .string(forKey: UserDefaultsKeys.ttsVoice)
        return KeyboardInstalledModels(
            dictation: KeyboardDictationModelStatus.availability(),
            isTTSReady: KeyboardModelAvailability.isTTSReady(preferredVoiceID: preferredTTSVoiceID)
        )
    }
}
