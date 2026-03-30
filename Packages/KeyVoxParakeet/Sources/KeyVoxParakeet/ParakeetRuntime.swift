import Foundation

internal protocol ParakeetRuntimeBackend: AnyObject {
    func transcribe(audioFrames: [Float], params: ParakeetParams) async throws -> ParakeetTranscriptionResult
    func cancelCurrentTranscription()
    func unload()
}

internal final class ParakeetRuntime {
    typealias BackendFactory = (URL) throws -> (any ParakeetRuntimeBackend)?

    private let lock = NSLock()
    private var activeRequestID = UUID()
    private var backend: (any ParakeetRuntimeBackend)?

    init(modelURL: URL, backendFactory: BackendFactory? = nil) throws {
        guard modelURL.isFileURL else {
            throw ParakeetError.initializationFailed
        }

        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw ParakeetError.modelNotFound
        }

        if let backendFactory {
            self.backend = try backendFactory(modelURL)
        } else {
            self.backend = try Self.makeDefaultBackend(modelURL: modelURL)
        }
    }

    func transcribe(audioFrames: [Float], params: ParakeetParams) async throws -> ParakeetTranscriptionResult {
        guard !audioFrames.isEmpty else {
            throw ParakeetError.invalidFrames
        }

        let requestID = beginRequest()
        guard let backend = currentBackend() else {
            return try failForMissingBackend(requestID: requestID)
        }

        let result = try await backend.transcribe(audioFrames: audioFrames, params: params)
        guard isCurrentRequest(requestID) else {
            throw ParakeetError.cancelled
        }
        return result
    }

    func cancelCurrentTranscription() {
        let backend = currentBackend()
        invalidateCurrentRequest()
        backend?.cancelCurrentTranscription()
    }

    func unload() {
        let backendToUnload = currentBackend()
        invalidateCurrentRequest()
        backendToUnload?.unload()
        lock.lock()
        backend = nil
        lock.unlock()
    }

    private func failForMissingBackend(requestID: UUID) throws -> ParakeetTranscriptionResult {
        if isCurrentRequest(requestID) {
            throw ParakeetError.runtimeUnavailable
        }
        throw ParakeetError.cancelled
    }

    private func beginRequest() -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let requestID = UUID()
        activeRequestID = requestID
        return requestID
    }

    private func invalidateCurrentRequest() {
        lock.lock()
        activeRequestID = UUID()
        lock.unlock()
    }

    private func isCurrentRequest(_ requestID: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeRequestID == requestID
    }

    private func currentBackend() -> (any ParakeetRuntimeBackend)? {
        lock.lock()
        defer { lock.unlock() }
        return backend
    }

    private static func makeDefaultBackend(modelURL: URL) throws -> (any ParakeetRuntimeBackend)? {
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: modelURL.path, isDirectory: &isDirectory) else {
            throw ParakeetError.modelNotFound
        }

        guard isDirectory.boolValue else {
            return nil
        }

        return try ParakeetCoreMLBackend(modelDirectoryURL: modelURL)
    }
}
