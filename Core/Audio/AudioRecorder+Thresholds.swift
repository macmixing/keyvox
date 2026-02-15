import Foundation
import AVFoundation
import CoreAudio

extension AudioRecorder {
    static func captureAudioDevices() -> [AVCaptureDevice] {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        return discovery.devices
    }

    func configureSessionSilenceThresholds(for device: AVCaptureDevice) {
        let inputVolume = Self.inputVolumeScalar(for: device) ?? AudioSilenceGatePolicy.defaultInputVolumeScalar
        let thresholdScale = AudioSilenceGatePolicy.thresholdScale(forInputVolume: inputVolume)

        sessionInputVolumeScalar = inputVolume
        sessionThresholdScale = thresholdScale
        sessionActiveSignalRMSThreshold = baseActiveSignalRMSThreshold * thresholdScale
        sessionGapRemovalRMSThreshold = baseGapRemovalRMSThreshold * thresholdScale
        sessionLikelySilenceRMSCutoff = AudioSilenceGatePolicy.lowConfidenceRMSCutoff * thresholdScale
        sessionTrueSilenceWindowRMSThreshold = AudioSilenceGatePolicy.trueSilenceWindowRMSThreshold * thresholdScale

        #if DEBUG
        print(
            "Audio thresholds configured: inputVolume=\(String(format: "%.2f", inputVolume)) " +
            "scale=\(String(format: "%.2f", thresholdScale)) " +
            "activeRMS=\(sessionActiveSignalRMSThreshold) " +
            "gapRMS=\(sessionGapRemovalRMSThreshold) " +
            "likelySilenceRMS=\(sessionLikelySilenceRMSCutoff) " +
            "trueSilenceRMS=\(sessionTrueSilenceWindowRMSThreshold)"
        )
        #endif
    }

    private static func inputVolumeScalar(for device: AVCaptureDevice) -> Float? {
        let deviceUID = device.uniqueID as CFString
        var deviceID = AudioDeviceID(kAudioObjectUnknown)
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDeviceForUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let status = withUnsafePointer(to: deviceUID) { uidPointer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                UInt32(MemoryLayout<CFString>.size),
                uidPointer,
                &dataSize,
                &deviceID
            )
        }

        guard status == noErr, deviceID != kAudioObjectUnknown else { return nil }
        return inputVolumeScalar(forAudioDeviceID: deviceID)
    }

    private static func inputVolumeScalar(forAudioDeviceID deviceID: AudioDeviceID) -> Float? {
        let candidateElements: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2]
        for element in candidateElements {
            var address = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyVolumeScalar,
                mScope: kAudioDevicePropertyScopeInput,
                mElement: element
            )
            guard AudioObjectHasProperty(deviceID, &address) else { continue }

            var volumeScalar: Float32 = 0
            var dataSize = UInt32(MemoryLayout<Float32>.size)
            let status = AudioObjectGetPropertyData(
                deviceID,
                &address,
                0,
                nil,
                &dataSize,
                &volumeScalar
            )
            guard status == noErr else { continue }
            return min(max(volumeScalar, 0), 1)
        }
        return nil
    }
}
