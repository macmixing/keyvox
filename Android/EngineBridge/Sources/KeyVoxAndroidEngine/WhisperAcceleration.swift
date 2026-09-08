import Foundation
import KeyVoxModels
import KeyVoxWhisper

struct WhisperAcceleration: Sendable {
    let installer: EncoderArtifactInstaller?
    let runtimeDirectory: URL
    private static let pluginFilename = "libKeyVoxWhisperQnn.so"

    init(models: URL, runtimeDirectory: URL, socIdentifier: String) {
        self.runtimeDirectory = runtimeDirectory
        let plugin = runtimeDirectory.appendingPathComponent(Self.pluginFilename)
        if FileManager.default.fileExists(atPath: plugin.path),
           let artifact = WhisperEncoderArtifact.qualcommArtifact(socIdentifier: socIdentifier) {
            installer = EncoderArtifactInstaller(directory: models, artifact: artifact)
        } else {
            installer = nil
        }
    }

    func makeWhisper(model: URL, params: WhisperParams) -> Whisper {
        let configuration: WhisperEncoderConfiguration?
        if let installer, installer.isReady() {
            configuration = WhisperEncoderConfiguration(
                pluginURL: runtimeDirectory.appendingPathComponent(Self.pluginFilename),
                modelURL: installer.modelURL, runtimeDirectory: runtimeDirectory)
        } else {
            configuration = nil
        }
        let whisper = Whisper(fromFileURL: model, withParams: params, encoderConfiguration: configuration)
        print("KeyVox encoder configured: \(whisper.isExternalEncoderConfigured)")
        return whisper
    }
}
