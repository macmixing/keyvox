import AVFoundation
import AudioToolbox
import CoreAudio

private final class AudioInputCallbackGate {
    private let lock = NSLock()
    private let group = DispatchGroup()
    private var isOpen = false

    func open() {
        lock.lock()
        isOpen = true
        lock.unlock()
    }

    func performIfOpen(_ work: () -> Void) {
        lock.lock()
        guard isOpen else {
            lock.unlock()
            return
        }
        group.enter()
        lock.unlock()

        defer { group.leave() }
        work()
    }

    func closeAndWait() {
        lock.lock()
        isOpen = false
        lock.unlock()
        group.wait()
    }
}

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
    private let callbackGate = AudioInputCallbackGate()
    private(set) var deviceUID: String?

    func start(
        deviceUID: String,
        deliveryQueue: DispatchQueue,
        bufferHandler: @escaping (AVAudioPCMBuffer) -> Void
    ) throws {
        if let engine, self.deviceUID == deviceUID {
            callbackGate.open()
            do {
                engine.prepare()
                try engine.start()
                return
            } catch {
                callbackGate.closeAndWait()
                throw error
            }
        }

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

        let callbackGate = callbackGate
        inputNode.installTap(onBus: 0, bufferSize: 512, format: inputFormat) { buffer, _ in
            callbackGate.performIfOpen {
                guard let copiedBuffer = Self.copy(buffer) else { return }
                deliveryQueue.async {
                    bufferHandler(copiedBuffer)
                }
            }
        }

        callbackGate.open()
        do {
            engine.prepare()
            try engine.start()
        } catch {
            callbackGate.closeAndWait()
            inputNode.removeTap(onBus: 0)
            throw error
        }

        self.engine = engine
        self.inputNode = inputNode
        self.deviceUID = deviceUID
    }

    func stop() {
        callbackGate.closeAndWait()
        engine?.stop()
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
