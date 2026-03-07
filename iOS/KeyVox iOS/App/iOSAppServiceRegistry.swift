import Foundation
import KeyVoxCore

@MainActor
final class iOSAppServiceRegistry {
    static let shared = iOSAppServiceRegistry()

    let dictionaryStore: DictionaryStore
    let whisperService: WhisperService
    let postProcessor: TranscriptionPostProcessor
    let artifactWriter: Phase2CaptureArtifactWriter
    let transcriptionManager: iOSTranscriptionManager
    let urlRouter: KeyVoxURLRouter

    private init(fileManager: FileManager = .default) {
        let dictionaryBaseDirectory = iOSSharedPaths.dictionaryBaseDirectoryURL(fileManager: fileManager)
            ?? iOSSharedPaths.fallbackBaseDirectoryURL(fileManager: fileManager)
        let modelPathProvider = {
            iOSSharedPaths.modelFileURL(fileManager: fileManager)?.path
        }

        let dictionaryStore = DictionaryStore(
            fileManager: fileManager,
            baseDirectoryURL: dictionaryBaseDirectory
        )
        let whisperService = WhisperService(modelPathResolver: modelPathProvider)
        let postProcessor = TranscriptionPostProcessor()
        let artifactWriter = Phase2CaptureArtifactWriter()
        let transcriptionManager = iOSTranscriptionManager(
            recorder: iOSAudioRecorder(),
            artifactWriter: artifactWriter,
            transcriptionService: whisperService,
            dictionaryStore: dictionaryStore,
            postProcessor: postProcessor,
            modelPathProvider: modelPathProvider
        )

        self.dictionaryStore = dictionaryStore
        self.whisperService = whisperService
        self.postProcessor = postProcessor
        self.artifactWriter = artifactWriter
        self.transcriptionManager = transcriptionManager
        self.urlRouter = KeyVoxURLRouter(transcriptionManager: transcriptionManager)
    }
}
