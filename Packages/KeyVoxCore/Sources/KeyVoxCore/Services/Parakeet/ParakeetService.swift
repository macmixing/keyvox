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
    let parakeetLoader: ParakeetLoader
    private var activeTranscriptionRequestID = UUID()
    var warmupHandle: WarmupHandle?

    var parakeet: Parakeet?
    var dictionaryHintPrompt = ""
    var transcriptionTask: Task<Void, Never>?
    let paragraphChunker = AudioParagraphChunker()

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
}
