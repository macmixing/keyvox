import Dispatch
import Foundation
import KeyVoxParakeet

/// Optional native backend. Loads lazily on its worker, independently of UI lifetime.
/// Cancellation discards results; native work and safe model release finish later.
public final class NativeParakeetBackend: ParakeetRuntimeBackend, @unchecked Sendable {
    private let worker = DispatchQueue(label: "KeyVoxParakeetNative.inference")
    private let lock = NSLock()
    private var requestID = UUID()
    private var unloaded = false
    private let sessionOwner: NativeParakeetSessionOwner

    public convenience init(modelURL: URL) throws {
        guard modelURL.isFileURL else { throw ParakeetError.initializationFailed }
        guard FileManager.default.fileExists(atPath: modelURL.path) else { throw ParakeetError.modelNotFound }
        self.init(makeSession: { try NativeParakeetSessionFactory.make(modelURL: modelURL) })
    }

    init(makeSession: @escaping () throws -> any NativeParakeetSession) {
        sessionOwner = NativeParakeetSessionOwner(makeSession: makeSession)
    }

    public func transcribe(audioFrames: [Float], params: ParakeetParams) async throws -> ParakeetTranscriptionResult {
        guard !audioFrames.isEmpty, audioFrames.count <= Int(Int32.max),
              audioFrames.allSatisfy(\.isFinite) else { throw ParakeetError.invalidFrames }
        let id = try beginRequest()
        return try await withTaskCancellationHandler {
            try Task.checkCancellation()
            return try await withCheckedThrowingContinuation { continuation in
                worker.async { [self] in
                    do {
                        guard isCurrent(id) else { throw ParakeetError.cancelled }
                        let session = try sessionOwner.session()
                        guard isCurrent(id) else { throw ParakeetError.cancelled }
                        let result = try session.transcribe(audioFrames, params: params)
                        guard isCurrent(id) else { throw ParakeetError.cancelled }
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: isCurrent(id) ? error : ParakeetError.cancelled)
                    }
                }
            }
        } onCancel: {
            self.cancelRequest(id)
        }
    }

    public func cancelCurrentTranscription() {
        lock.lock()
        requestID = UUID()
        lock.unlock()
    }

    public func unload() {
        lock.lock()
        guard !unloaded else { lock.unlock(); return }
        unloaded = true
        requestID = UUID()
        lock.unlock()
        worker.async { [sessionOwner] in sessionOwner.close() }
    }

    deinit { unload() }

    private func beginRequest() throws -> UUID {
        lock.lock()
        defer { lock.unlock() }
        guard !unloaded else { throw ParakeetError.runtimeUnavailable }
        requestID = UUID()
        return requestID
    }

    private func isCurrent(_ id: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return !unloaded && requestID == id
    }

    private func cancelRequest(_ id: UUID) {
        lock.lock()
        if requestID == id { requestID = UUID() }
        lock.unlock()
    }
}
