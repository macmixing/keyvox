import Foundation
import KeyVoxTTS

protocol TTSEngine {
    var isPreparedForSynthesis: Bool { get }

    func prepareIfNeeded() async throws
    func prewarmVoiceIfNeeded(voiceID: String) async throws
    func unloadIfNeeded()
    func requestForegroundSynthesisImmediately()
    func requestBackgroundContinuationImmediately()
    func prepareForForegroundSynthesis() async
    func prepareForBackgroundContinuation() async
    func makeAudioStream(
        for text: String,
        voiceID: String,
        fastModeEnabled: Bool
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>
}
