import Foundation
import KeyVoxSpeechRuntime

// Only the Apple whisper.cpp runtime provides the streaming detection calls this detector needs.
#if canImport(whisper)
/// Follows how likely live 16 kHz mono audio is to be speech, one model window at a time,
/// carrying the model's memory from each window into the next.
///
/// Not thread safe: the owner calls it from one serial context.
public final class LiveVoiceActivityDetector {
    /// Samples the model reads for each prediction at 16 kHz.
    private static let windowSampleCount = 512

    private let context: OpaquePointer
    private var pendingSamples: [Float] = []

    /// The speech probability of the latest complete window, from 0 to 1.
    public private(set) var speechProbability: Float = 0

    public convenience init?() {
        guard let modelURL = VoiceActivityModelResource.bundledURL else {
            return nil
        }
        self.init(modelURL: modelURL)
    }

    public init?(modelURL: URL) {
        WhisperRuntimeLogFilter.install

        var params = whisper_vad_default_context_params()
        params.n_threads = 1
        params.use_gpu = false
        params.gpu_device = 0

        guard let context = modelURL.path.withCString({
            whisper_vad_init_from_file_with_params($0, params)
        }) else {
            return nil
        }
        self.context = context
        pendingSamples.reserveCapacity(Self.windowSampleCount * 2)
    }

    deinit {
        whisper_vad_free(context)
    }

    /// Adds the next audio samples and returns the speech probability of the latest complete window.
    @discardableResult
    public func append(_ samples: [Float]) -> Float {
        pendingSamples.append(contentsOf: samples)

        var consumedSampleCount = 0
        while pendingSamples.count - consumedSampleCount >= Self.windowSampleCount {
            let didDetect = pendingSamples.withUnsafeBufferPointer { buffer in
                whisper_vad_detect_speech_no_reset(
                    context,
                    buffer.baseAddress! + consumedSampleCount,
                    Int32(Self.windowSampleCount)
                )
            }
            if didDetect,
               whisper_vad_n_probs(context) > 0,
               let probabilities = whisper_vad_probs(context) {
                speechProbability = probabilities[0]
            }
            consumedSampleCount += Self.windowSampleCount
        }
        if consumedSampleCount > 0 {
            pendingSamples.removeFirst(consumedSampleCount)
        }

        return speechProbability
    }

    /// Clears the model's memory and any partial window before a new capture.
    public func reset() {
        whisper_vad_reset_state(context)
        pendingSamples.removeAll(keepingCapacity: true)
        speechProbability = 0
    }
}
#endif
