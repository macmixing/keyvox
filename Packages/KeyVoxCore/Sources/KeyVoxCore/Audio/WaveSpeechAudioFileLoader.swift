import Foundation

struct WaveSpeechAudioFileLoader: SpeechAudioFileLoading {
    func load(url: URL) throws -> [Float] {
        let audio = try WavePCMDecoder.decode(Data(contentsOf: url))
        return try PCMResampler.resample(audio.samples, from: audio.sampleRate, to: 16_000)
    }
}
