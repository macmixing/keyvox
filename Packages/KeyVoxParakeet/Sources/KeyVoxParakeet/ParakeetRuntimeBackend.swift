import Foundation

/// Speech inference supplied by a platform model runtime.
/// Implementations must allow cancellation and unloading while inference is active.
public protocol ParakeetRuntimeBackend: AnyObject {
    func transcribe(audioFrames: [Float], params: ParakeetParams) async throws -> ParakeetTranscriptionResult
    func cancelCurrentTranscription()
    func unload()
}
