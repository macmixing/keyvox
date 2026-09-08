import Foundation
@preconcurrency import KeyVoxSpeechRuntime

public struct WhisperTranscriptionResult: Sendable {
    public let segments: [Segment]
    public let detectedLanguageCode: String?
    public let detectedLanguageName: String?

    public init(segments: [Segment], detectedLanguageCode: String?, detectedLanguageName: String?) {
        self.segments = segments
        self.detectedLanguageCode = detectedLanguageCode
        self.detectedLanguageName = detectedLanguageName
    }
}

private struct WhisperContextHandle: @unchecked Sendable {
    let raw: OpaquePointer
}

struct WhisperRuntime {
    var configureEncoder: (OpaquePointer, WhisperEncoderConfiguration) -> Bool = WhisperEncoderConfiguration.configure
    var contextDefaultParams: () -> whisper_context_params
    var initFromFileWithParams: (_ path: UnsafePointer<CChar>, _ params: whisper_context_params) -> OpaquePointer?
    var freeContext: (_ context: OpaquePointer) -> Void
    var full: (
        _ context: OpaquePointer,
        _ params: whisper_full_params,
        _ samples: UnsafePointer<Float>?,
        _ sampleCount: Int32
    ) -> Int32
    var fullNSegments: (_ context: OpaquePointer) -> Int32
    var fullGetSegmentText: (_ context: OpaquePointer, _ index: Int32) -> UnsafePointer<CChar>?
    var fullGetSegmentT0: (_ context: OpaquePointer, _ index: Int32) -> Int64
    var fullGetSegmentT1: (_ context: OpaquePointer, _ index: Int32) -> Int64
    var fullGetSegmentNoSpeechProb: (_ context: OpaquePointer, _ index: Int32) -> Float
    var fullLangId: (_ context: OpaquePointer) -> Int32
    var fixedModelLanguageId: (_ context: OpaquePointer) -> Int32?
    var langStr: (_ id: Int32) -> UnsafePointer<CChar>?
    var langStrFull: (_ id: Int32) -> UnsafePointer<CChar>?

    static let live = WhisperRuntime(
        contextDefaultParams: { whisper_context_default_params() },
        initFromFileWithParams: { path, params in
            whisper_init_from_file_with_params(path, params)
        },
        freeContext: { context in
            whisper_free(context)
        },
        full: { context, params, samples, sampleCount in
            whisper_full(context, params, samples, sampleCount)
        },
        fullNSegments: { context in
            whisper_full_n_segments(context)
        },
        fullGetSegmentText: { context, index in
            whisper_full_get_segment_text(context, index)
        },
        fullGetSegmentT0: { context, index in
            whisper_full_get_segment_t0(context, index)
        },
        fullGetSegmentT1: { context, index in
            whisper_full_get_segment_t1(context, index)
        },
        fullGetSegmentNoSpeechProb: { context, index in
            whisper_full_get_segment_no_speech_prob(context, index)
        },
        fullLangId: { context in
            whisper_full_lang_id(context)
        },
        fixedModelLanguageId: WhisperModelLanguage.fixedLanguageID,
        langStr: { id in
            whisper_lang_str(id)
        },
        langStrFull: { id in
            whisper_lang_str_full(id)
        }
    )
}

public final class Whisper {
    private static let minimumInferenceFrameCount = 16_800
    private static let venturaMajorVersion = 13

    private let runtime: WhisperRuntime
    private let inferenceQueue: DispatchQueue
    private let whisperContext: OpaquePointer?
    private let paramsLock = NSLock()
    private var storedParams: WhisperParams
    /// Whether the optional encoder attached successfully during initialization.
    /// A subsequent runtime failure can fall back to native encoding.
    public let isExternalEncoderConfigured: Bool
    public var params: WhisperParams {
        get { paramsLock.withLock { storedParams } }
        set { paramsLock.withLock { storedParams = newValue } }
    }

    public init(fromFileURL fileURL: URL, withParams params: WhisperParams = .default,
                computePolicy: WhisperComputePolicy = .automatic,
                encoderConfiguration: WhisperEncoderConfiguration? = nil) {
        self.runtime = .live
        self.inferenceQueue = Self.makeInferenceQueue()
        self.storedParams = params
        self.whisperContext = Self.makeContext(
            fileURL: fileURL,
            computePolicy: computePolicy,
            runtime: runtime,
            osVersionProvider: { ProcessInfo.processInfo.operatingSystemVersion }
        )
        if let whisperContext, let encoderConfiguration {
            self.isExternalEncoderConfigured = runtime.configureEncoder(whisperContext, encoderConfiguration)
        } else {
            self.isExternalEncoderConfigured = false
        }
    }

    init(
        fromFileURL fileURL: URL,
        withParams params: WhisperParams = .default,
        computePolicy: WhisperComputePolicy = .automatic,
        encoderConfiguration: WhisperEncoderConfiguration? = nil,
        runtime: WhisperRuntime,
        osVersionProvider: @escaping () -> OperatingSystemVersion,
        inferenceQueue: DispatchQueue
    ) {
        self.runtime = runtime
        self.inferenceQueue = Self.makeInferenceQueue(target: inferenceQueue)
        self.storedParams = params
        self.whisperContext = Self.makeContext(
            fileURL: fileURL,
            computePolicy: computePolicy,
            runtime: runtime,
            osVersionProvider: osVersionProvider
        )
        if let whisperContext, let encoderConfiguration {
            self.isExternalEncoderConfigured = runtime.configureEncoder(whisperContext, encoderConfiguration)
        } else {
            self.isExternalEncoderConfigured = false
        }
    }

    deinit {
        if let whisperContext {
            runtime.freeContext(whisperContext)
        }
    }

    public func transcribe(audioFrames: [Float]) async throws -> [Segment] {
        try await transcribeWithMetadata(audioFrames: audioFrames).segments
    }

    public func transcribeWithMetadata(audioFrames: [Float]) async throws -> WhisperTranscriptionResult {
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

        let paramsSnapshot = params.snapshot()
        let context = WhisperContextHandle(raw: whisperContext)
        let runtime = self.runtime
        let inferenceQueue = self.inferenceQueue

        return try await withCheckedThrowingContinuation { continuation in
            inferenceQueue.async { [self] in
                // Keep the native context and owned request strings alive through result extraction.
                defer {
                    withExtendedLifetime(self) {}
                    withExtendedLifetime(paramsSnapshot) {}
                }
                var localParams = paramsSnapshot.raw
                let fixedLanguageID = runtime.fixedModelLanguageId(context.raw)
                if let fixedLanguageID {
                    guard fixedLanguageID >= 0, let language = runtime.langStr(fixedLanguageID) else {
                        continuation.resume(throwing: WhisperError.initializationFailed)
                        return
                    }
                    localParams.language = language
                    localParams.detect_language = false
                }

                let status = framesForInference.withUnsafeBufferPointer { buffer in
                    runtime.full(
                        context.raw,
                        localParams,
                        buffer.baseAddress,
                        Int32(buffer.count)
                    )
                }

                guard status == 0 else {
                    continuation.resume(throwing: WhisperError.transcriptionFailed(code: status))
                    return
                }

                let segmentCount = Int(runtime.fullNSegments(context.raw))
                var segments: [Segment] = []
                segments.reserveCapacity(segmentCount)

                if segmentCount > 0 {
                    for index in 0..<segmentCount {
                        guard let cText = runtime.fullGetSegmentText(context.raw, Int32(index)) else {
                            continue
                        }

                        let startTime = Int(runtime.fullGetSegmentT0(context.raw, Int32(index)) * 10)
                        let endTime = Int(runtime.fullGetSegmentT1(context.raw, Int32(index)) * 10)
                        let text = String(cString: cText)
                        let noSpeechProbability = runtime.fullGetSegmentNoSpeechProb(context.raw, Int32(index))

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

                let reportedLanguageID = runtime.fullLangId(context.raw)
                let langId = fixedLanguageID ?? reportedLanguageID
                #if DEBUG
                print("Whisper language diagnostic: fixedModelId=\(String(describing: fixedLanguageID)) reportedId=\(reportedLanguageID) effectiveId=\(langId)")
                #endif
                let langCode: String?
                let langName: String?

                if langId >= 0 {
                    langCode = runtime.langStr(langId).map { String(cString: $0) }
                    langName = runtime.langStrFull(langId).map { String(cString: $0) }
                } else {
                    langCode = nil
                    langName = nil
                }

                let result = WhisperTranscriptionResult(
                    segments: segments,
                    detectedLanguageCode: langCode,
                    detectedLanguageName: langName
                )

                continuation.resume(returning: result)
            }
        }
    }

    private static func makeInferenceQueue(target: DispatchQueue? = nil) -> DispatchQueue {
        DispatchQueue(label: "KeyVoxWhisper.inference", qos: .userInitiated, target: target)
    }

    private static func makeContext(
        fileURL: URL,
        computePolicy: WhisperComputePolicy,
        runtime: WhisperRuntime,
        osVersionProvider: () -> OperatingSystemVersion
    ) -> OpaquePointer? {
        let osVersion = osVersionProvider()
        let isVentura = osVersion.majorVersion == venturaMajorVersion
        var contextParams = runtime.contextDefaultParams()
        #if os(iOS)
        let shouldDisableGPU = true
        let shouldRetryWithCPUFallback = false
        #elseif os(macOS)
        let shouldDisableGPU = isVentura
        let shouldRetryWithCPUFallback = isVentura
        #else
        let shouldDisableGPU = false
        let shouldRetryWithCPUFallback = contextParams.use_gpu
        #endif

        if shouldDisableGPU || computePolicy == .gpuDisabled {
            // iOS background transcription cannot submit Metal work reliably, and Ventura has
            // a known upstream crash path during Metal init, so both paths force CPU for now.
            contextParams.use_gpu = false
            contextParams.flash_attn = false
        }

        let context = fileURL.path.withCString { path in
            runtime.initFromFileWithParams(path, contextParams)
        }

        if context != nil || shouldRetryWithCPUFallback == false || computePolicy == .gpuDisabled {
            return context
        }

        // Retry context initialization with explicit CPU settings. This cannot recover
        // from a driver crash or an error after inference has started.
        var fallbackParams = runtime.contextDefaultParams()
        fallbackParams.use_gpu = false
        fallbackParams.flash_attn = false
        return fileURL.path.withCString { path in
            runtime.initFromFileWithParams(path, fallbackParams)
        }
    }
}
