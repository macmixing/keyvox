import AVFoundation
import AudioToolbox

/// An Audio Unit that renders no audio: the keyboard hosts it for its message channel, which
/// runs dictation in this extension's process.
final class TranscriptionAU: AUAudioUnit {
    private var inputBusArray: AUAudioUnitBusArray!
    private var outputBusArray: AUAudioUnitBusArray!
    private let dictationMessageChannel = TranscriptionAUMessageChannel()

    override init(
        componentDescription: AudioComponentDescription,
        options: AudioComponentInstantiationOptions = []
    ) throws {
        try super.init(componentDescription: componentDescription, options: options)
        let format = AudioCaptureTuning.outputFormat
        inputBusArray = AUAudioUnitBusArray(
            audioUnit: self,
            busType: .input,
            busses: [try AUAudioUnitBus(format: format)]
        )
        outputBusArray = AUAudioUnitBusArray(
            audioUnit: self,
            busType: .output,
            busses: [try AUAudioUnitBus(format: format)]
        )
    }

    override var inputBusses: AUAudioUnitBusArray { inputBusArray }
    override var outputBusses: AUAudioUnitBusArray { outputBusArray }

    override var internalRenderBlock: AUInternalRenderBlock {
        { _, _, _, _, _, _, _ in kAudioUnitErr_NoConnection }
    }

    override func messageChannel(for channelName: String) -> any AUMessageChannel {
        guard channelName == TranscriptionAUContract.messageChannelName else {
            return super.messageChannel(for: channelName)
        }
        return dictationMessageChannel
    }
}
