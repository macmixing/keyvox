import Foundation

/// Converts an audio file to mono, 16 kHz inference samples.
protocol SpeechAudioFileLoading {
    func load(url: URL) throws -> [Float]
}

enum SpeechAudioFileLoader {
    static func load(url: URL) throws -> [Float] {
        #if canImport(AVFoundation)
        return try AppleSpeechAudioFileLoader().load(url: url)
        #else
        return try WaveSpeechAudioFileLoader().load(url: url)
        #endif
    }
}
