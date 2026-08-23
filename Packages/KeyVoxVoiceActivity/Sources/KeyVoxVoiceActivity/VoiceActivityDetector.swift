import Foundation
import KeyVoxSpeechRuntime

public struct VoiceActivitySegment: Equatable, Sendable {
    public let startTime: Float
    public let endTime: Float

    public init(startTime: Float, endTime: Float) {
        self.startTime = startTime
        self.endTime = endTime
    }
}

public struct VoiceActivityAnalysis: Equatable, Sendable {
    public let probabilities: [Float]
    public let speechSegments: [VoiceActivitySegment]

    public var containsSpeech: Bool {
        !speechSegments.isEmpty
    }

    public init(
        probabilities: [Float],
        speechSegments: [VoiceActivitySegment]
    ) {
        self.probabilities = probabilities
        self.speechSegments = speechSegments
    }
}

public actor VoiceActivityDetector: VoiceActivityAnalyzing {
    private var context: OpaquePointer?

    public init?() {
        guard let modelURL = Bundle.module.url(
            forResource: "ggml-silero-v5.1.2",
            withExtension: "bin"
        ) else {
            return nil
        }
        self.init(modelURL: modelURL)
    }

    public init?(
        modelURL: URL,
        threadCount: Int32 = 4
    ) {
        var params = whisper_vad_default_context_params()
        params.n_threads = threadCount
        params.use_gpu = false
        params.gpu_device = 0

        context = modelURL.path.withCString {
            whisper_vad_init_from_file_with_params($0, params)
        }
        guard context != nil else { return nil }
    }

    deinit {
        if let context {
            whisper_vad_free(context)
        }
    }

    public func analyze(
        audioFrames: [Float],
        configuration: VoiceActivityConfiguration = .standard
    ) -> VoiceActivityAnalysis? {
        guard let context else { return nil }
        guard !audioFrames.isEmpty else {
            return VoiceActivityAnalysis(
                probabilities: [],
                speechSegments: []
            )
        }

        let didAnalyze = audioFrames.withUnsafeBufferPointer { buffer in
            whisper_vad_detect_speech(
                context,
                buffer.baseAddress,
                Int32(buffer.count)
            )
        }
        guard didAnalyze else { return nil }

        let probabilityCount = Int(whisper_vad_n_probs(context))
        let probabilities: [Float]
        if probabilityCount > 0, let probabilityPointer = whisper_vad_probs(context) {
            probabilities = Array(
                UnsafeBufferPointer(
                    start: probabilityPointer,
                    count: probabilityCount
                )
            )
        } else {
            probabilities = []
        }

        var params = whisper_vad_default_params()
        params.threshold = configuration.threshold
        params.min_speech_duration_ms = configuration.minimumSpeechDurationMilliseconds
        params.min_silence_duration_ms = configuration.minimumSilenceDurationMilliseconds
        params.speech_pad_ms = configuration.speechPaddingMilliseconds

        guard let rawSegments = whisper_vad_segments_from_probs(context, params) else {
            return nil
        }
        defer {
            whisper_vad_free_segments(rawSegments)
        }

        let segmentCount = Int(whisper_vad_segments_n_segments(rawSegments))
        let speechSegments = (0..<segmentCount).map { index in
            VoiceActivitySegment(
                startTime: whisper_vad_segments_get_segment_t0(rawSegments, Int32(index)),
                endTime: whisper_vad_segments_get_segment_t1(rawSegments, Int32(index))
            )
        }

        return VoiceActivityAnalysis(
            probabilities: probabilities,
            speechSegments: speechSegments
        )
    }
}
