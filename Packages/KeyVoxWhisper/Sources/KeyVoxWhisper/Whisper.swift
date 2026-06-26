import Foundation
@preconcurrency import whisper

public struct WhisperTranscriptionResult: Sendable {
    public let segments: [Segment]
    public let detectedLanguageCode: String?
    public let detectedLanguageName: String?

    public init(segments: [Segment], detectedLanguageCode: String?, detectedLanguageName: String?) {
        self.segments = segments
        self.detectedLanguageCode = detectedLanguageCode
        self.detectedLanguageName = detectedLanguageName
    }

    var hasValidTiming: Bool {
        segments.allSatisfy { segment in
            segment.startTime >= 0 && segment.endTime >= segment.startTime
        }
    }
}

private struct WhisperContextHandle: @unchecked Sendable {
    let raw: OpaquePointer
}

private struct WhisperParamsHandle: @unchecked Sendable {
    let raw: whisper_full_params
}

struct WhisperRuntime {
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
    private let cpuFallbackContext: OpaquePointer?
    private let fallbackStateLock = NSLock()
    private var prefersCPUFallbackAfterInvalidPrimaryTiming = false
    public var params: WhisperParams

    private static func log(_ message: String) {
        print("[KeyVoxWhisper] \(message)")
    }

    public init(fromFileURL fileURL: URL, withParams params: WhisperParams = .default) {
        self.runtime = .live
        self.inferenceQueue = DispatchQueue.global(qos: .userInitiated)
        self.params = params
        self.whisperContext = Self.makeContext(
            fileURL: fileURL,
            runtime: runtime,
            osVersionProvider: { ProcessInfo.processInfo.operatingSystemVersion }
        )
        self.cpuFallbackContext = Self.makeCPUFallbackContext(
            fileURL: fileURL,
            runtime: runtime,
            osVersionProvider: { ProcessInfo.processInfo.operatingSystemVersion }
        )
    }

    init(
        fromFileURL fileURL: URL,
        withParams params: WhisperParams = .default,
        runtime: WhisperRuntime,
        osVersionProvider: @escaping () -> OperatingSystemVersion,
        inferenceQueue: DispatchQueue
    ) {
        self.runtime = runtime
        self.inferenceQueue = inferenceQueue
        self.params = params
        self.whisperContext = Self.makeContext(
            fileURL: fileURL,
            runtime: runtime,
            osVersionProvider: osVersionProvider
        )
        self.cpuFallbackContext = Self.makeCPUFallbackContext(
            fileURL: fileURL,
            runtime: runtime,
            osVersionProvider: osVersionProvider
        )
    }

    deinit {
        if let whisperContext {
            runtime.freeContext(whisperContext)
        }
        if let cpuFallbackContext {
            runtime.freeContext(cpuFallbackContext)
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

        let paramsSnapshot = WhisperParamsHandle(raw: params.whisperParams)
        let context = WhisperContextHandle(raw: whisperContext)
        let fallbackContext = cpuFallbackContext.map { WhisperContextHandle(raw: $0) }
        let runtime = self.runtime
        let inferenceQueue = self.inferenceQueue
        let shouldPreferCPUFallback = prefersCPUFallbackContext()

        let runResult: TranscriptionRunResult = try await withCheckedThrowingContinuation { continuation in
            inferenceQueue.async {
                let localParams = paramsSnapshot.raw
                let primaryAttempt = TranscriptionAttempt(context: context, isCPUFallback: false)
                let fallbackAttempt = fallbackContext.map {
                    TranscriptionAttempt(context: $0, isCPUFallback: true)
                }
                let attempts: [TranscriptionAttempt]
                if shouldPreferCPUFallback, let fallbackAttempt {
                    attempts = [fallbackAttempt]
                } else if let fallbackAttempt {
                    attempts = [primaryAttempt, fallbackAttempt]
                } else {
                    attempts = [primaryAttempt]
                }
                var sawUnusablePrimaryResult = false

                for attempt in attempts {
                    Self.log("Starting \(attempt.logName) transcription path.")
                    let status = framesForInference.withUnsafeBufferPointer { buffer in
                        runtime.full(
                            attempt.context.raw,
                            localParams,
                            buffer.baseAddress,
                            Int32(buffer.count)
                        )
                    }

                    guard status == 0 else {
                        if attempt.context.raw == attempts.last?.context.raw {
                            Self.log("\(attempt.logName) transcription path failed with status=\(status).")
                            continuation.resume(throwing: WhisperError.transcriptionFailed(code: status))
                            return
                        }
                        Self.log("\(attempt.logName) transcription path failed with status=\(status); retrying CPU fallback.")
                        continue
                    }

                    let result = Self.transcriptionResult(from: attempt.context.raw, runtime: runtime)
                    if attempt.isCPUFallback == false,
                       result.segments.isEmpty,
                       attempt.context.raw != attempts.last?.context.raw {
                        Self.log("\(attempt.logName) transcription path produced no segments; retrying CPU fallback.")
                        sawUnusablePrimaryResult = true
                        continue
                    }

                    guard result.hasValidTiming else {
                        if attempt.context.raw == attempts.last?.context.raw {
                            Self.log("\(attempt.logName) transcription path produced invalid timestamps.")
                            continuation.resume(throwing: WhisperError.transcriptionFailed(code: -1))
                            return
                        }
                        Self.log("\(attempt.logName) transcription path produced invalid timestamps; retrying CPU fallback.")
                        if attempt.isCPUFallback == false {
                            sawUnusablePrimaryResult = true
                        }
                        continue
                    }

                    Self.log("\(attempt.logName) transcription path succeeded.")
                    continuation.resume(
                        returning: TranscriptionRunResult(
                            result: result,
                            shouldPreferCPUFallback: attempt.isCPUFallback && sawUnusablePrimaryResult && result.segments.isEmpty == false
                        )
                    )
                    return
                }

                continuation.resume(throwing: WhisperError.transcriptionFailed(code: -1))
            }
        }

        if runResult.shouldPreferCPUFallback {
            markCPUFallbackPreferredAfterInvalidPrimaryTiming()
        }
        return runResult.result
    }

    private func prefersCPUFallbackContext() -> Bool {
        fallbackStateLock.lock()
        defer { fallbackStateLock.unlock() }
        return prefersCPUFallbackAfterInvalidPrimaryTiming
    }

    private func markCPUFallbackPreferredAfterInvalidPrimaryTiming() {
        fallbackStateLock.lock()
        prefersCPUFallbackAfterInvalidPrimaryTiming = true
        fallbackStateLock.unlock()
    }

    private struct TranscriptionAttempt {
        let context: WhisperContextHandle
        let isCPUFallback: Bool

        var logName: String {
            isCPUFallback ? "CPU fallback" : "primary"
        }
    }

    private struct TranscriptionRunResult {
        let result: WhisperTranscriptionResult
        let shouldPreferCPUFallback: Bool
    }

    private static func transcriptionResult(
        from context: OpaquePointer,
        runtime: WhisperRuntime
    ) -> WhisperTranscriptionResult {
        let segmentCount = Int(runtime.fullNSegments(context))
        var segments: [Segment] = []
        segments.reserveCapacity(segmentCount)

        if segmentCount > 0 {
            for index in 0..<segmentCount {
                guard let cText = runtime.fullGetSegmentText(context, Int32(index)) else {
                    continue
                }

                let startTime = Int(runtime.fullGetSegmentT0(context, Int32(index)) * 10)
                let endTime = Int(runtime.fullGetSegmentT1(context, Int32(index)) * 10)
                let text = String(cString: cText)
                let noSpeechProbability = runtime.fullGetSegmentNoSpeechProb(context, Int32(index))

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

        let langId = runtime.fullLangId(context)
        let langCode: String?
        let langName: String?

        if langId >= 0 {
            langCode = runtime.langStr(langId).map { String(cString: $0) }
            langName = runtime.langStrFull(langId).map { String(cString: $0) }
        } else {
            langCode = nil
            langName = nil
        }

        return WhisperTranscriptionResult(
            segments: segments,
            detectedLanguageCode: langCode,
            detectedLanguageName: langName
        )
    }

    private static func makeContext(
        fileURL: URL,
        runtime: WhisperRuntime,
        osVersionProvider: () -> OperatingSystemVersion
    ) -> OpaquePointer? {
        let osVersion = osVersionProvider()
        let isVentura = osVersion.majorVersion == venturaMajorVersion
        #if os(iOS)
        let shouldDisableGPU = true
        let shouldRetryWithCPUFallback = false
        #else
        let shouldDisableGPU = isVentura
        let shouldRetryWithCPUFallback = isVentura
        #endif

        var contextParams = runtime.contextDefaultParams()
        if shouldDisableGPU {
            // iOS background transcription cannot submit Metal work reliably, and Ventura has
            // a known upstream crash path during Metal init, so both paths force CPU for now.
            contextParams.use_gpu = false
            contextParams.flash_attn = false
        }

        let context = fileURL.path.withCString { path in
            runtime.initFromFileWithParams(path, contextParams)
        }

        if context != nil || shouldRetryWithCPUFallback == false {
            return context
        }

        // Retry once on Ventura with explicit CPU settings.
        var fallbackParams = runtime.contextDefaultParams()
        fallbackParams.use_gpu = false
        fallbackParams.flash_attn = false
        return fileURL.path.withCString { path in
            runtime.initFromFileWithParams(path, fallbackParams)
        }
    }

    private static func makeCPUFallbackContext(
        fileURL: URL,
        runtime: WhisperRuntime,
        osVersionProvider: () -> OperatingSystemVersion
    ) -> OpaquePointer? {
        guard let fallbackURL = makeCPUFallbackModelURL(for: fileURL) else {
            return nil
        }
        return makeContext(
            fileURL: fallbackURL,
            runtime: runtime,
            osVersionProvider: osVersionProvider
        )
    }

    private static func makeCPUFallbackModelURL(for fileURL: URL) -> URL? {
        let fallbackDirectoryURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent(".cpu-fallback", isDirectory: true)
        let fallbackURL = fallbackDirectoryURL.appendingPathComponent(fileURL.lastPathComponent)
        let encoderURL = fileURL
            .deletingLastPathComponent()
            .appendingPathComponent("\(fileURL.deletingPathExtension().lastPathComponent)-encoder.mlmodelc")
        let fallbackEncoderURL = fallbackDirectoryURL.appendingPathComponent(encoderURL.lastPathComponent)
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }

        do {
            try fileManager.createDirectory(
                at: fallbackDirectoryURL,
                withIntermediateDirectories: true
            )

            try linkOrSymlinkItemIfNeeded(
                from: fileURL,
                to: fallbackURL,
                fileManager: fileManager
            )

            if fileManager.fileExists(atPath: encoderURL.path) {
                try linkOrSymlinkItemIfNeeded(
                    from: encoderURL,
                    to: fallbackEncoderURL,
                    fileManager: fileManager
                )
            }

            return fallbackURL
        } catch {
            return nil
        }
    }

    private static func linkOrSymlinkItemIfNeeded(
        from sourceURL: URL,
        to destinationURL: URL,
        fileManager: FileManager
    ) throws {
        if fileManager.fileExists(atPath: destinationURL.path) {
            return
        }

        do {
            try fileManager.linkItem(at: sourceURL, to: destinationURL)
        } catch {
            try fileManager.createSymbolicLink(at: destinationURL, withDestinationURL: sourceURL)
        }
    }
}
