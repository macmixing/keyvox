import Foundation
import KeyVoxParakeet

extension ParakeetService {
    public func warmup() {
        _ = scheduleWarmupIfNeeded()
    }

    public func unloadModel() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        warmupHandle?.task.cancel()
        warmupHandle = nil
        parakeet?.unload()
        parakeet = nil
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
        let initialPrompt = dictionaryHintPrompt
        let loader = parakeetLoader
        let task = Task.detached(priority: .userInitiated) {
            do {
                return try loader(modelURL, initialPrompt)
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
            }
            return
        }

        warmupHandle = nil

        if let parakeet {
            if let warmedParakeet, parakeet !== warmedParakeet {
                warmedParakeet.unload()
            }
            return
        }

        parakeet = warmedParakeet
        parakeet?.params.initialPrompt = dictionaryHintPrompt
    }

    nonisolated static func makeParakeet(modelURL: URL, initialPrompt: String) throws -> Parakeet? {
        let params = ParakeetParams.default
        params.initialPrompt = initialPrompt
        return try Parakeet(fromModelURL: modelURL, withParams: params)
    }
}
