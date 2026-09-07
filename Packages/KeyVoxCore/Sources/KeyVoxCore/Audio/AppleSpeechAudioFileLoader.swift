#if canImport(AVFoundation)
import AVFoundation
import Foundation

struct AppleSpeechAudioFileLoader: SpeechAudioFileLoading {
    func load(url: URL) throws -> [Float] {
        let inputFile = try AVAudioFile(forReading: url)
        let inputFormat = inputFile.processingFormat

        let outputFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false)!

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw NSError(domain: "WhisperService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create converter"])
        }

        let ratio = 16000.0 / inputFormat.sampleRate
        let outputCapacity = AVAudioFrameCount(Double(inputFile.length) * ratio) + 1

        guard let outputBuffer = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: outputCapacity) else {
            throw NSError(domain: "WhisperService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create buffer"])
        }

        var error: NSError?
        let inputBlock: AVAudioConverterInputBlock = { inNumPackets, outStatus in
            let inputBuffer = AVAudioPCMBuffer(pcmFormat: inputFormat, frameCapacity: inNumPackets)!
            do {
                try inputFile.read(into: inputBuffer)
                outStatus.pointee = .haveData
                return inputBuffer
            } catch {
                outStatus.pointee = .noDataNow
                return nil
            }
        }

        let status = converter.convert(to: outputBuffer, error: &error, withInputFrom: inputBlock)

        if status == .error {
            throw error ?? NSError(domain: "WhisperService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Conversion failed"])
        }

        guard let floatData = outputBuffer.floatChannelData else { return [] }
        return Array(UnsafeBufferPointer(start: floatData[0], count: Int(outputBuffer.frameLength)))
    }

}
#endif
