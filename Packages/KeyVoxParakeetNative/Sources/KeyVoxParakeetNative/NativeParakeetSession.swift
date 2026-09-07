import Foundation
import KeyVoxParakeet
import CParakeet

/// All methods, including close, are called serially by the owning backend.
protocol NativeParakeetSession: AnyObject {
    func transcribe(_ frames: [Float], params: ParakeetParams) throws -> ParakeetTranscriptionResult
    func close()
}

enum NativeParakeetSessionFactory {
    static func make(modelURL: URL) throws -> any NativeParakeetSession {
        #if os(Android) || os(Linux)
        return try CParakeetSession(modelURL: modelURL)
        #else
        throw ParakeetError.runtimeUnavailable
        #endif
    }
}

#if os(Android) || os(Linux)
private final class CParakeetSession: NativeParakeetSession {
    private var context: OpaquePointer?
    private static let sampleRate: Int32 = 16_000

    init(modelURL: URL) throws {
        guard parakeet_capi_abi_version() == 6 else { throw ParakeetError.runtimeUnavailable }
        guard let context = modelURL.path.withCString({ parakeet_capi_load($0) }) else {
            throw ParakeetError.initializationFailed
        }
        self.context = context
    }

    func transcribe(_ frames: [Float], params: ParakeetParams) throws -> ParakeetTranscriptionResult {
        guard let context else { throw ParakeetError.runtimeUnavailable }
        let output = frames.withUnsafeBufferPointer { buffer in
            if let language = params.languageCode {
                return language.withCString {
                    parakeet_capi_transcribe_pcm_lang(context, buffer.baseAddress,
                        Int32(buffer.count), Self.sampleRate, 0, $0)
                }
            }
            return parakeet_capi_transcribe_pcm_lang(context, buffer.baseAddress,
                Int32(buffer.count), Self.sampleRate, 0, nil)
        }
        guard let output else {
            let message = parakeet_capi_last_error(context).flatMap { String(validatingCString: $0) }
            throw ParakeetError.transcriptionFailed(code: -1, message: message)
        }
        defer { parakeet_capi_free_string(output) }
        guard let text = String(validatingCString: output) else {
            throw ParakeetError.transcriptionFailed(code: -1, message: nil)
        }
        // Match the existing backend's utterance segment contract. No fabricated
        // word timestamps, language detection, confidence, or alternative results.
        let segments = text.isEmpty ? [] : [ParakeetSegment(
            startTime: 0, endTime: Int(Double(frames.count) * 1_000 / Double(Self.sampleRate)), text: text
        )]
        return ParakeetTranscriptionResult(segments: segments)
    }

    func close() {
        if let context { parakeet_capi_free(context) }
        context = nil
    }
}
#endif
