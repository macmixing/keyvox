import Foundation

public final class Parakeet {
    private let runtime: ParakeetRuntime
    public let params: ParakeetParams

    public init(fromModelURL modelURL: URL, withParams params: ParakeetParams = .default) throws {
        self.params = params
        self.runtime = try ParakeetRuntime(modelURL: modelURL)
    }

    internal init(
        fromModelURL modelURL: URL,
        withParams params: ParakeetParams = .default,
        backendFactory: ParakeetRuntime.BackendFactory?
    ) throws {
        self.params = params
        self.runtime = try ParakeetRuntime(modelURL: modelURL, backendFactory: backendFactory)
    }

    public func transcribe(audioFrames: [Float]) async throws -> [ParakeetSegment] {
        try await transcribeWithMetadata(audioFrames: audioFrames).segments
    }

    public func transcribeWithMetadata(audioFrames: [Float]) async throws -> ParakeetTranscriptionResult {
        try await runtime.transcribe(audioFrames: audioFrames, params: params)
    }

    public func cancelCurrentTranscription() {
        runtime.cancelCurrentTranscription()
    }

    public func unload() {
        runtime.unload()
    }
}
