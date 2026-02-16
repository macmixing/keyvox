import Foundation
import whisper

public final class Whisper {
    private static let minimumInferenceFrameCount = 16_800
    private static let venturaMajorVersion = 13

    private let whisperContext: OpaquePointer?
    public var params: WhisperParams

    public init(fromFileURL fileURL: URL, withParams params: WhisperParams = .default) {
        self.params = params
        self.whisperContext = Self.makeContext(fileURL: fileURL)
    }

    deinit {
        if let whisperContext {
            whisper_free(whisperContext)
        }
    }

    public func transcribe(audioFrames: [Float]) async throws -> [Segment] {
        try Task.checkCancellation()

        guard !audioFrames.isEmpty else {
            throw WhisperError.invalidFrames
        }
        guard let whisperContext else {
            throw WhisperError.initializationFailed
        }

        let framesForInference: [Float]
        if audioFrames.count < Self.minimumInferenceFrameCount {
            // Add a small safety margin above 1s to avoid borderline short-clip failures.
            let paddingCount = Self.minimumInferenceFrameCount - audioFrames.count
            framesForInference = audioFrames + Array(repeating: 0, count: paddingCount)
        } else {
            framesForInference = audioFrames
        }

        let paramsSnapshot = params.whisperParams

        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var localParams = paramsSnapshot

                let status = framesForInference.withUnsafeBufferPointer { buffer in
                    whisper_full(
                        whisperContext,
                        localParams,
                        buffer.baseAddress,
                        Int32(buffer.count)
                    )
                }

                guard status == 0 else {
                    continuation.resume(throwing: WhisperError.transcriptionFailed(code: status))
                    return
                }

                let segmentCount = Int(whisper_full_n_segments(whisperContext))
                var segments: [Segment] = []
                segments.reserveCapacity(segmentCount)

                if segmentCount > 0 {
                    for index in 0..<segmentCount {
                        guard let cText = whisper_full_get_segment_text(whisperContext, Int32(index)) else {
                            continue
                        }

                        let startTime = Int(whisper_full_get_segment_t0(whisperContext, Int32(index)) * 10)
                        let endTime = Int(whisper_full_get_segment_t1(whisperContext, Int32(index)) * 10)
                        let text = String(cString: cText)
                        let noSpeechProbability = whisper_full_get_segment_no_speech_prob(whisperContext, Int32(index))

                        segments.append(
                            Segment(
                                startTime: startTime,
                                endTime: endTime,
                                text: text,
                                noSpeechProbability: noSpeechProbability
                            )
                        )
                    }
                }

                continuation.resume(returning: segments)
            }
        }
    }

    private static func makeContext(fileURL: URL) -> OpaquePointer? {
        let osVersion = ProcessInfo.processInfo.operatingSystemVersion
        let isVentura = osVersion.majorVersion == venturaMajorVersion

        var contextParams = whisper_context_default_params()
        if isVentura {
            // Ventura-specific stability guard: avoid Metal init crash path in upstream binary.
            contextParams.use_gpu = false
            contextParams.flash_attn = false
        }

        let context = fileURL.path.withCString { path in
            whisper_init_from_file_with_params(path, contextParams)
        }

        if context != nil || !isVentura {
            return context
        }

        // Retry once on Ventura with explicit CPU settings.
        var fallbackParams = whisper_context_default_params()
        fallbackParams.use_gpu = false
        fallbackParams.flash_attn = false
        return fileURL.path.withCString { path in
            whisper_init_from_file_with_params(path, fallbackParams)
        }
    }
}
