import Foundation
import KeyVoxWhisper

extension WhisperService {
    /// Pre-loads the model into memory to eliminate cold-start latency.
    func warmup() {
        guard whisper == nil else {
            #if DEBUG
            print("WhisperService: Warmup skipped (model already loaded).")
            #endif
            return
        }
        guard let modelPath = getModelPath() else {
            #if DEBUG
            print("WhisperService: Warmup skipped (model files not found).")
            #endif
            return
        }

        #if DEBUG
        print("Warming up Whisper model with optimized settings...")
        #endif

        let params = WhisperParams.default
        params.language = .auto
        params.n_threads = 4 // Optimal for M-series P-cores (prevent oversubscription)
        params.no_context = true
        params.print_timestamps = false
        params.suppress_blank = true
        params.suppress_non_speech_tokens = true
        params.temperature = 0.0
        params.temperature_inc = 0.0
        params.no_speech_thold = 0.6
        params.logprob_thold = -0.8
        params.initialPrompt = isPromptHintingEnabled ? dictionaryHintPrompt : ""
        // CoreML is automatic if the model files are present

        whisper = Whisper(fromFileURL: URL(fileURLWithPath: modelPath), withParams: params)
    }

    /// Unloads the currently cached model instance.
    /// Used when model files are deleted so re-download can warm from disk again.
    func unloadModel() {
        guard whisper != nil else { return }
        whisper = nil
        #if DEBUG
        print("WhisperService: Unloaded model from memory.")
        #endif
    }

    private func getModelPath() -> String? {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let modelsDir = appSupport
            .appendingPathComponent("KeyVox")
            .appendingPathComponent("Models")

        let baseModelURL = modelsDir.appendingPathComponent("ggml-base.bin")
        if FileManager.default.fileExists(atPath: baseModelURL.path) {
            return baseModelURL.path
        }

        return nil
    }
}
