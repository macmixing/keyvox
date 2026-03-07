import Foundation

@MainActor
final class iOSAppServiceRegistry {
    static let shared = iOSAppServiceRegistry()

    let artifactWriter: Phase2CaptureArtifactWriter
    let transcriptionManager: iOSTranscriptionManager
    let urlRouter: KeyVoxURLRouter

    private init() {
        let artifactWriter = Phase2CaptureArtifactWriter()
        let transcriptionManager = iOSTranscriptionManager(artifactWriter: artifactWriter)

        self.artifactWriter = artifactWriter
        self.transcriptionManager = transcriptionManager
        self.urlRouter = KeyVoxURLRouter(transcriptionManager: transcriptionManager)
    }
}
