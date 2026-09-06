import AVFoundation
import AudioToolbox
import CoreAudio

final class AudioEngineInputCapture {
    enum CaptureError: Error {
        case deviceNotFound
        case audioUnitUnavailable
        case deviceSelectionFailed(OSStatus)
        case streamFormatSelectionFailed(OSStatus)
        case invalidInputFormat
    }

    private var engine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    func start(
        deviceUID: String,
        deliveryQueue: DispatchQueue,
        bufferHandler: @escaping (AVAudioPCMBuffer) -> Void
    ) throws {
        guard var deviceID = Self.audioDeviceID(forUID: deviceUID) else {
            throw CaptureError.deviceNotFound
        }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        guard let audioUnit = inputNode.audioUnit else {
            throw CaptureError.audioUnitUnavailable
        }

        let selectionStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &deviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
        guard selectionStatus == noErr else {
            throw CaptureError.deviceSelectionFailed(selectionStatus)
        }

        var hardwareInputFormat = inputNode.inputFormat(forBus: 0).streamDescription.pointee
        let formatSelectionStatus = AudioUnitSetProperty(
            audioUnit,
            kAudioUnitProperty_StreamFormat,
            kAudioUnitScope_Output,
            1,
            &hardwareInputFormat,
            UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
        )
        guard formatSelectionStatus == noErr else {
            throw CaptureError.streamFormatSelectionFailed(formatSelectionStatus)
        }

        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw CaptureError.invalidInputFormat
        }

        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: inputFormat) { buffer, _ in
            guard let copiedBuffer = Self.copy(buffer) else { return }
            deliveryQueue.async {
                bufferHandler(copiedBuffer)
            }
        }

        engine.prepare()
        try engine.start()

        self.engine = engine
        self.inputNode = inputNode
    }

    func stop() {
        inputNode?.removeTap(onBus: 0)
        engine?.stop()
        inputNode = nil
        engine = nil
    }

    private static func audioDeviceID(forUID deviceUID: String) -> AudioDeviceID? {
        var uid = deviceUID as CFString
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = withUnsafeMutablePointer(to: &uid) { uidPointer in
            withUnsafeMutablePointer(to: &deviceID) { deviceIDPointer in
                var translation = AudioValueTranslation(
                    mInputData: uidPointer,
                    mInputDataSize: UInt32(MemoryLayout<CFString>.size),
                    mOutputData: deviceIDPointer,
                    mOutputDataSize: UInt32(MemoryLayout<AudioDeviceID>.size)
                )
                var translationSize = UInt32(MemoryLayout<AudioValueTranslation>.size)
                return AudioObjectGetPropertyData(
                    AudioObjectID(kAudioObjectSystemObject),
                    &address,
                    0,
                    nil,
                    &translationSize,
                    &translation
                )
            }
        }

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return deviceID
    }

    private static func copy(_ source: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let destination = AVAudioPCMBuffer(
            pcmFormat: source.format,
            frameCapacity: source.frameLength
        ) else {
            return nil
        }

        destination.frameLength = source.frameLength
        let sourceBuffers = UnsafeMutableAudioBufferListPointer(source.mutableAudioBufferList)
        let destinationBuffers = UnsafeMutableAudioBufferListPointer(destination.mutableAudioBufferList)

        for (sourceBuffer, destinationBuffer) in zip(sourceBuffers, destinationBuffers) {
            guard let sourceData = sourceBuffer.mData,
                  let destinationData = destinationBuffer.mData else {
                return nil
            }
            memcpy(
                destinationData,
                sourceData,
                Int(min(sourceBuffer.mDataByteSize, destinationBuffer.mDataByteSize))
            )
        }

        return destination
    }
}
