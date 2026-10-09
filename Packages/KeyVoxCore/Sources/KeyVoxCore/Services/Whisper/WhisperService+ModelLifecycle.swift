import Foundation
import KeyVoxWhisper
import KeyVoxVoiceActivity

extension WhisperService {
    /// Pre-loads the voice activity detector and model off the main actor to eliminate cold-start latency.
    public func warmup() {
        _ = scheduleWarmupIfNeeded()
    }

    /// Unloads the currently cached model instance.
    /// Used when model files are deleted so re-download can warm from disk again.
    public func unloadModel() {
        warmupHandle?.task.cancel()
        warmupHandle = nil
        guard whisper != nil || voiceActivityDetector != nil else { return }
        whisper = nil
        voiceActivityDetector = nil
        #if DEBUG
        print("WhisperService: Unloaded model from memory.")
        #endif
    }

    public func preloadIfNeeded() async {
        guard let handle = scheduleWarmupIfNeeded() else { return }
        await installWarmupResultIfCurrent(handle)
    }

    func scheduleWarmupIfNeeded() -> WarmupHandle? {
        if let warmupHandle {
            return warmupHandle
        }

        let detectorFactory = voiceActivityDetector == nil ? voiceActivityDetectorFactory : nil
        let modelLoad = pendingModelLoad()
        guard detectorFactory != nil || modelLoad != nil else { return nil }

        let whisperFactory = self.whisperFactory
        // Both loads stay sequential: the detector initializes the shared Whisper runtime before the model does.
        let task = Task.detached(priority: .userInitiated) {
            await SpeechModelLoadQueue.load {
                #if DEBUG
                var loadStartedAt = Date()
                #endif
                let detector = detectorFactory?()
                #if DEBUG
                if detectorFactory != nil {
                    print("WhisperService: Voice activity detector loaded in \(WhisperService.elapsedSeconds(since: loadStartedAt))s.")
                }
                loadStartedAt = Date()
                #endif
                let whisper = modelLoad.map { whisperFactory($0.url, $0.params) }
                #if DEBUG
                if modelLoad != nil {
                    print("WhisperService: Model loaded in \(WhisperService.elapsedSeconds(since: loadStartedAt))s.")
                }
                #endif
                return WarmupResult(voiceActivityDetector: detector, whisper: whisper)
            }
        }

        let handle = WarmupHandle(id: UUID(), task: task)
        warmupHandle = handle
        Task { [weak self] in
            await self?.installWarmupResultIfCurrent(handle)
        }
        return handle
    }

    func installWarmupResultIfCurrent(_ handle: WarmupHandle) async {
        let result = await handle.task.value

        guard warmupHandle?.id == handle.id else { return }
        warmupHandle = nil

        if voiceActivityDetector == nil {
            voiceActivityDetector = result.voiceActivityDetector
        }
        if whisper == nil {
            whisper = result.whisper
        }
    }

    private func pendingModelLoad() -> (url: URL, params: WhisperParams)? {
        guard whisper == nil else {
            #if DEBUG
            print("WhisperService: Warmup skipped (model already loaded).")
            #endif
            return nil
        }
        guard let modelPath = getModelPath() else {
            #if DEBUG
            print("WhisperService: Warmup skipped (model files not found).")
            #endif
            return nil
        }

        #if DEBUG
        print("Warming up Whisper model with optimized settings...")
        #endif

        let params = WhisperParams.default
        applyConfiguredLanguage(to: params)
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

        return (URL(fileURLWithPath: modelPath), params)
    }

    private func getModelPath() -> String? {
        guard let modelPath = resolvedModelPath(),
              FileManager.default.fileExists(atPath: modelPath) else {
            return nil
        }
        return modelPath
    }

    #if DEBUG
    private nonisolated static func elapsedSeconds(since date: Date) -> String {
        String(format: "%.2f", Date().timeIntervalSince(date))
    }
    #endif
}
