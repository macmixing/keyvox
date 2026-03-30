import Foundation
import Combine
import KeyVoxParakeet

@MainActor
public final class ParakeetService: ObservableObject, DictationProvider {
    typealias ParakeetLoader = (_ modelURL: URL, _ initialPrompt: String) throws -> Parakeet?

    struct WarmupHandle {
        let id: UUID
        let task: Task<Parakeet?, Never>
    }

    @Published public internal(set) var isTranscribing = false
    @Published public internal(set) var transcriptionText = ""
    @Published public internal(set) var lastResultWasLikelyNoSpeech = false

    private let modelURLResolver: () -> URL?
    private let parakeetLoader: ParakeetLoader
    private var activeTranscriptionRequestID = UUID()
    private var warmupHandle: WarmupHandle?

    var parakeet: Parakeet?
    var dictionaryHintPrompt = ""
    var transcriptionTask: Task<Void, Never>?

    public init(modelURLResolver: @escaping () -> URL? = { nil }) {
        self.modelURLResolver = modelURLResolver
        self.parakeetLoader = Self.makeParakeet
    }

    init(
        modelURLResolver: @escaping () -> URL? = { nil },
        parakeetLoader: @escaping ParakeetLoader
    ) {
        self.modelURLResolver = modelURLResolver
        self.parakeetLoader = parakeetLoader
    }

    public var isModelReady: Bool {
        guard let modelURL = resolvedModelURL() else { return false }
        return FileManager.default.fileExists(atPath: modelURL.path)
    }

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

    public func cancelTranscription() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
        activeTranscriptionRequestID = UUID()
        isTranscribing = false
        parakeet?.cancelCurrentTranscription()
    }

    public func updateDictionaryHintPrompt(_ prompt: String) {
        let cleanedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        dictionaryHintPrompt = cleanedPrompt
        parakeet?.params.initialPrompt = cleanedPrompt
    }

    public func preloadIfNeeded() async {
        guard parakeet == nil else { return }
        guard let handle = scheduleWarmupIfNeeded() else { return }
        await installWarmupResultIfCurrent(handle)
    }

    public func transcribe(
        audioFrames: [Float],
        useDictionaryHintPrompt: Bool,
        enableAutoParagraphs: Bool,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        let requestID = beginTranscriptionRequest()
        transcriptionTask?.cancel()
        transcriptionTask = nil

        guard !audioFrames.isEmpty else {
            finishEmptyRequest(requestID, completion: completion)
            return
        }

        isTranscribing = true
        lastResultWasLikelyNoSpeech = false

        transcriptionTask = Task { [weak self] in
            guard let self else { return }
            guard let parakeet = await self.loadedParakeet() else {
                self.finishFailedRequest(requestID, completion: completion)
                return
            }

            if useDictionaryHintPrompt {
                parakeet.params.initialPrompt = self.dictionaryHintPrompt
            } else {
                parakeet.params.initialPrompt = ""
            }

            do {
                let result = try await parakeet.transcribeWithMetadata(audioFrames: audioFrames)
                if Task.isCancelled {
                    self.finishCancelledRequest(requestID)
                    return
                }

                let finalText = self.normalizeWhitespace(
                    result.segments.map(\.text).joined(separator: enableAutoParagraphs ? "\n\n" : " "),
                    preservingNewlines: enableAutoParagraphs
                )
                let likelyNoSpeech = finalText.isEmpty
                self.finishSuccessfulRequest(
                    requestID,
                    finalText: finalText,
                    likelyNoSpeech: likelyNoSpeech,
                    detectedLanguageCode: result.detectedLanguageCode,
                    completion: completion
                )
            } catch let error as ParakeetError {
                if case .cancelled = error {
                    self.finishCancelledRequest(requestID)
                    return
                }
                self.finishFailedRequest(requestID, completion: completion)
            } catch {
                if Task.isCancelled {
                    self.finishCancelledRequest(requestID)
                    return
                }
                self.finishFailedRequest(requestID, completion: completion)
            }
        }
    }

    func resolvedModelURL() -> URL? {
        modelURLResolver()
    }

    func beginTranscriptionRequest() -> UUID {
        let requestID = UUID()
        activeTranscriptionRequestID = requestID
        return requestID
    }

    func isCurrentRequest(_ requestID: UUID) -> Bool {
        activeTranscriptionRequestID == requestID
    }

    func finishCancelledRequest(_ requestID: UUID) {
        guard isCurrentRequest(requestID) else { return }
        transcriptionTask = nil
        isTranscribing = false
    }

    func finishEmptyRequest(
        _ requestID: UUID,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        guard isCurrentRequest(requestID) else { return }
        transcriptionTask = nil
        isTranscribing = false
        lastResultWasLikelyNoSpeech = true
        transcriptionText = ""
        completion(TranscriptionProviderResult(text: "", languageCode: nil))
    }

    func finishSuccessfulRequest(
        _ requestID: UUID,
        finalText: String,
        likelyNoSpeech: Bool,
        detectedLanguageCode: String?,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        guard isCurrentRequest(requestID) else { return }
        transcriptionTask = nil
        isTranscribing = false
        lastResultWasLikelyNoSpeech = likelyNoSpeech
        transcriptionText = finalText
        completion(TranscriptionProviderResult(text: finalText, languageCode: detectedLanguageCode))
    }

    func finishFailedRequest(
        _ requestID: UUID,
        completion: @escaping (TranscriptionProviderResult?) -> Void
    ) {
        guard isCurrentRequest(requestID) else { return }
        transcriptionTask = nil
        isTranscribing = false
        lastResultWasLikelyNoSpeech = false
        completion(nil)
    }

    private func normalizeWhitespace(_ text: String, preservingNewlines: Bool = false) -> String {
        let normalized = preservingNewlines
            ? text
                .split(separator: "\n", omittingEmptySubsequences: false)
                .map { line in
                    line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                }
                .joined(separator: "\n")
            : text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func scheduleWarmupIfNeeded() -> WarmupHandle? {
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

    private func loadedParakeet() async -> Parakeet? {
        if let parakeet {
            return parakeet
        }

        guard let handle = scheduleWarmupIfNeeded() else {
            return parakeet
        }

        await installWarmupResultIfCurrent(handle)
        return parakeet
    }

    private func installWarmupResultIfCurrent(_ handle: WarmupHandle) async {
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

    nonisolated private static func makeParakeet(modelURL: URL, initialPrompt: String) throws -> Parakeet? {
        let params = ParakeetParams.default
        params.initialPrompt = initialPrompt
        return try Parakeet(fromModelURL: modelURL, withParams: params)
    }
}
