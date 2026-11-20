import AudioToolbox
import Foundation

/// The message contract between the keyboard and the dictation Audio Unit extension it hosts.
/// The component codes repeat the ones in the extension's Info.plist, which cannot read code.
nonisolated enum DictationAudioUnitContract {
    static let messageChannelName = "com.cueit.keyvox.dictation"

    static var componentDescription: AudioComponentDescription {
        AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: fourCharacterCode("kvdc"),
            componentManufacturer: fourCharacterCode("KVox"),
            componentFlags: 0,
            componentFlagsMask: 0
        )
    }

    enum Command: String {
        /// Starts a dictation with the keyboard's selected Vibe; answers whether dictation can run.
        case begin
        /// Adds captured microphone audio; answers with the live meter for it.
        case appendAudio
        /// Ends the capture and starts transcription.
        case finish
        /// Answers with the current outcome.
        case poll
        /// Abandons the dictation.
        case cancel
        case releaseModels
    }

    enum Outcome: String {
        case pending
        case transcript
        case noSpeech
        case failed
    }

    enum Key {
        static let command = "command"
        static let styleIdentifier = "styleIdentifier"
        static let audio = "audio"
        static let sampleRate = "sampleRate"
        static let accepted = "accepted"
        static let meterLevel = "meterLevel"
        static let meterSignalState = "meterSignalState"
        static let outcome = "outcome"
        static let text = "text"
    }

    private static func fourCharacterCode(_ code: String) -> FourCharCode {
        code.utf8.reduce(0) { ($0 << 8) | FourCharCode($1) }
    }
}
