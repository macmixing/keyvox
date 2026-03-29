import Foundation
import Combine
import KeyVoxParakeet

@MainActor
public final class ParakeetService: ObservableObject, DictationProvider {
    @Published public internal(set) var isTranscribing = false
    @Published public internal(set) var transcriptionText = ""
    @Published public internal(set) var lastResultWasLikelyNoSpeech = false

    private let modelURLResolver: () -> URL?
    private var activeTranscriptionRequestID = UUID()

    var parakeet: Parakeet?
    var dictionaryHintPrompt = ""
    var transcriptionTask: Task<Void, Never>?

    public init(modelURLResolver: @escaping () -> URL? = { nil }) {
        self.modelURLResolver = modelURLResolver
    }

    public var isModelReady: Bool {
        guard let modelURL = resolvedModelURL() else { return false }
        return FileManager.default.fileExists(atPath: modelURL.path)
    }

    public func warmup() {
        guard parakeet == nil else { return }
        guard let modelURL = resolvedModelURL() else { return }

        do {
            let params = ParakeetParams.default
            params.initialPrompt = dictionaryHintPrompt
            parakeet = try Parakeet(fromModelURL: modelURL, withParams: params)
        } catch {
            #if DEBUG
            print("ParakeetService: Warmup skipped (\(error.localizedDescription)).")
            #endif
        }
    }

    public func unloadModel() {
        transcriptionTask?.cancel()
        transcriptionTask = nil
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

        if parakeet == nil {
            warmup()
        }

        guard let parakeet else {
            finishFailedRequest(requestID, completion: completion)
            return
        }

        if useDictionaryHintPrompt {
            parakeet.params.initialPrompt = dictionaryHintPrompt
        } else {
            parakeet.params.initialPrompt = ""
        }

        transcriptionTask = Task { [weak self] in
            guard let self else { return }

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
}
