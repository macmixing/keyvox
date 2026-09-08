import Foundation
import KeyVoxCore
import KeyVoxVoiceActivity

@MainActor
final class EngineSession {
    static var shared: EngineSession?
    let installer: ModelArtifactInstaller
    let dictionary: DictionaryStore
    let service: WhisperService
    private let postProcessorPreparation: Task<TranscriptionPostProcessor, Never>
    var pipeline: DictationPipeline?
    var request: Int64?
    var downloading = false
    var ready = false
    var configured = false

    init(resources: URL, models: URL, dictionaryDirectory: URL) throws {
        try KeyVoxCoreResources.configure(bundleURL: resources.appendingPathComponent("KeyVoxCore_KeyVoxCore.resources"))
        let vadDirectory = resources.appendingPathComponent("KeyVoxVoiceActivity_KeyVoxVoiceActivity.resources")
        let vadModels = try FileManager.default.contentsOfDirectory(at: vadDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "bin" }
        guard vadModels.count == 1 else { throw CocoaError(.fileReadCorruptFile) }
        let vadURL = vadModels[0]
        let installer = ModelArtifactInstaller(directory: models)
        self.installer = installer
        dictionary = DictionaryStore(baseDirectoryURL: dictionaryDirectory)
        service = WhisperService(modelPathResolver: { installer.modelURL.path },
            voiceActivityDetectorFactory: { VoiceActivityDetector(modelURL: vadURL) })
        postProcessorPreparation = Task.detached(priority: .userInitiated) {
            TranscriptionPostProcessor()
        }
    }

    func refreshModel() {
        let installer = installer
        Task {
            let verified = await Task.detached { installer.isReady() }.value
            ready = verified
            configured = true
            EngineEvent(kind: .configured, modelReady: verified).send()
        }
    }

    func download() {
        guard configured, !downloading, request == nil else { return }
        downloading = true
        EngineEvent(kind: .modelDownloading).send()
        let installer = installer
        Task {
            do {
                try await Task.detached { try await installer.install() }.value
                ready = true
                EngineEvent(kind: .modelReady, modelReady: true).send()
            } catch {
                EngineEvent(kind: .modelFailed, modelReady: ready).send()
            }
            downloading = false
        }
    }

    func transcribe(path: String, id: Int64) {
        guard ready, request == nil else { EngineEvent(kind: .failed, request: id).send(); return }
        request = id
        Task {
            do {
                let audioReadStart = ContinuousClock.now
                let frames = try await Task.detached { try CapturedAudio.read(path: path) }.value
                let audioReadMilliseconds = audioReadStart.duration(to: .now).milliseconds
                guard request == id else { return }
                let warmupStart = ContinuousClock.now
                service.warmup()
                let modelWarmupMilliseconds = warmupStart.duration(to: .now).milliseconds
                let pipelineStart = ContinuousClock.now
                let postProcessor = await postProcessorPreparation.value
                let postProcessorPreparationWaitMilliseconds = pipelineStart.duration(to: .now).milliseconds
                guard request == id else { return }
                let pipeline = DictationPipeline(transcriptionProvider: service,
                    postProcessor: postProcessor,
                    dictionaryEntriesProvider: { self.dictionary.entries },
                    autoParagraphsEnabledProvider: { true }, listFormattingEnabledProvider: { true },
                    listRenderModeProvider: { .multiline }, recordSpokenWords: { _ in }, pasteText: { _ in })
                self.pipeline = pipeline
                pipeline.run(audioFrames: frames, useDictionaryHintPrompt: false) { result in
                    guard self.request == id else { return }
                    self.request = nil
                    self.pipeline = nil
                    if result.finalText.isEmpty && !result.wasLikelyNoSpeech {
                        EngineEvent(kind: .failed, request: id).send()
                    } else {
                        EngineEvent(kind: .result, request: id, text: result.finalText, noSpeech: result.wasLikelyNoSpeech,
                            audioReadMilliseconds: audioReadMilliseconds, modelWarmupMilliseconds: modelWarmupMilliseconds,
                            inferenceMilliseconds: result.inferenceDuration * 1_000,
                            pipelineMilliseconds: pipelineStart.duration(to: .now).milliseconds,
                            postProcessorPreparationWaitMilliseconds: postProcessorPreparationWaitMilliseconds).send()
                    }
                }
            } catch {
                guard request == id else { return }
                request = nil
                EngineEvent(kind: .failed, request: id).send()
            }
        }
    }

    func cancel() {
        let id = request
        request = nil
        service.cancelTranscription()
        pipeline = nil
        EngineEvent(kind: .cancelled, request: id).send()
    }
}
