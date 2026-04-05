import Foundation
import KeyVoxTTS

protocol TTSEngine {
    func prepareIfNeeded() async throws
    func prepareForForegroundSynthesis() async
    func prepareForBackgroundContinuation() async
    func makeAudioStream(
        for text: String,
        voiceID: String,
        fastModeEnabled: Bool
    ) async throws -> AsyncThrowingStream<KeyVoxTTSAudioFrame, Error>
}
