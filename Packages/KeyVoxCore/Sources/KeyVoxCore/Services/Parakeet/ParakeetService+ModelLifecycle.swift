import Foundation
import KeyVoxParakeet
import KeyVoxVoiceActivity

extension ParakeetService {
    public func warmup() {
        _ = scheduleVoiceActivityWarmupIfNeeded()
        _ = scheduleWarmupIfNeeded()
    }

    public func unloadModel() {
        cancelTranscription()
        warmupHandle?.task.cancel()
        warmupHandle = nil
        voiceActivityWarmupHandle?.task.cancel()
        voiceActivityWarmupHandle = nil
        parakeet?.unload()
        logModelUnloadedIfNeeded(parakeet)
        parakeet = nil
        voiceActivityAnalyzer = nil
        isTranscribing = false
    }

    public func preloadIfNeeded() async {
        guard parakeet == nil else { return }
        guard let handle = scheduleWarmupIfNeeded() else { return }
        await installWarmupResultIfCurrent(handle)
    }

    func scheduleWarmupIfNeeded() -> WarmupHandle? {
        if let warmupHandle {
            return warmupHandle
        }

        if parakeet != nil {
            return nil
        }

        guard let modelURL = resolvedModelURL() else { return nil }

        let warmupID = UUID()
        let loader = parakeetLoader
        let task = Task.detached(priority: .userInitiated) {
            do {
                return try loader(modelURL)
            } catch {
                #if DEBUG
                print("ParakeetService: Warmup skipped (\(error.localizedDescription)).")
                #endif
                return nil
            }
        }

        let handle = WarmupHandle(id: warmupID, task: task)
        warmupHandle = handle
        Task { [weak self] in
            await self?.installWarmupResultIfCurrent(handle)
        }
        return handle
    }

    func loadedParakeet() async -> Parakeet? {
        if let parakeet {
            return parakeet
        }

        guard let handle = scheduleWarmupIfNeeded() else {
            return parakeet
        }

        await installWarmupResultIfCurrent(handle)
        return parakeet
    }

    func installWarmupResultIfCurrent(_ handle: WarmupHandle) async {
        let warmedParakeet = await handle.task.value

        guard warmupHandle?.id == handle.id else {
            if let warmedParakeet, parakeet !== warmedParakeet {
                warmedParakeet.unload()
                logModelUnloadedIfNeeded(warmedParakeet)
            }
            return
        }

        warmupHandle = nil

        if let parakeet {
            if let warmedParakeet, parakeet !== warmedParakeet {
                warmedParakeet.unload()
                logModelUnloadedIfNeeded(warmedParakeet)
            }
            return
        }

        parakeet = warmedParakeet
    }

    func scheduleVoiceActivityWarmupIfNeeded() -> VoiceActivityWarmupHandle? {
        if let voiceActivityWarmupHandle {
            return voiceActivityWarmupHandle
        }

        if voiceActivityAnalyzer != nil {
            return nil
        }

        let factory = voiceActivityAnalyzerFactory
        let task = Task.detached(priority: .userInitiated) {
            await SpeechModelLoadQueue.load(factory)
        }

        let handle = VoiceActivityWarmupHandle(id: UUID(), task: task)
        voiceActivityWarmupHandle = handle
        Task { [weak self] in
            await self?.installVoiceActivityWarmupResultIfCurrent(handle)
        }
        return handle
    }

    func loadedVoiceActivityAnalyzer() async -> (any VoiceActivityAnalyzing)? {
        if let voiceActivityAnalyzer {
            return voiceActivityAnalyzer
        }

        guard let handle = scheduleVoiceActivityWarmupIfNeeded() else {
            return voiceActivityAnalyzer
        }

        await installVoiceActivityWarmupResultIfCurrent(handle)
        return voiceActivityAnalyzer
    }

    func installVoiceActivityWarmupResultIfCurrent(_ handle: VoiceActivityWarmupHandle) async {
        let warmedAnalyzer = await handle.task.value

        guard voiceActivityWarmupHandle?.id == handle.id else { return }
        voiceActivityWarmupHandle = nil

        if voiceActivityAnalyzer == nil {
            voiceActivityAnalyzer = warmedAnalyzer
        }
    }

    nonisolated static func makeParakeet(modelURL: URL) throws -> Parakeet? {
        try Parakeet(fromModelURL: modelURL, withParams: .default)
    }

    private func logModelUnloadedIfNeeded(_ parakeet: Parakeet?) {
        guard parakeet != nil else { return }
        #if DEBUG
        print("ParakeetService: Unloaded model from memory.")
        #endif
    }
}
