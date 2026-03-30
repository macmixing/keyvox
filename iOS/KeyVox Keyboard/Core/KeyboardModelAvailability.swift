import Foundation

enum KeyboardModelAvailability {
    static func isInstalled(fileManager: FileManager = .default) -> Bool {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: KeyVoxIPCBridge.appGroupID
        ) else {
            return false
        }

        let modelsDirectory = containerURL.appendingPathComponent("Models", isDirectory: true)
        return whisperIsInstalled(in: modelsDirectory, fileManager: fileManager)
            || parakeetIsInstalled(in: modelsDirectory, fileManager: fileManager)
    }

    private static func whisperIsInstalled(in modelsDirectory: URL, fileManager: FileManager) -> Bool {
        let whisperRootURL = modelsDirectory.appendingPathComponent("whisper", isDirectory: true)
        let ggmlModelURL = whisperRootURL.appendingPathComponent("ggml-base.bin", isDirectory: false)
        let coreMLDirectoryURL = whisperRootURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
        let coreMLZipURL = whisperRootURL.appendingPathComponent("ggml-base-encoder.mlmodelc.zip", isDirectory: false)
        let manifestURL = whisperRootURL.appendingPathComponent("install-manifest.json", isDirectory: false)

        return fileManager.fileExists(atPath: ggmlModelURL.path)
            && fileManager.fileExists(atPath: coreMLDirectoryURL.path)
            && !fileManager.fileExists(atPath: coreMLZipURL.path)
            && fileManager.fileExists(atPath: manifestURL.path)
    }

    private static func parakeetIsInstalled(in modelsDirectory: URL, fileManager: FileManager) -> Bool {
        let parakeetRootURL = modelsDirectory.appendingPathComponent("parakeet", isDirectory: true)
        let manifestURL = parakeetRootURL.appendingPathComponent("install-manifest.json", isDirectory: false)
        let configURL = parakeetRootURL.appendingPathComponent("config.json", isDirectory: false)
        let vocabURL = parakeetRootURL.appendingPathComponent("parakeet_vocab.json", isDirectory: false)
        let jointModelURL = parakeetRootURL.appendingPathComponent("JointDecision.mlmodelc", isDirectory: true)

        return fileManager.fileExists(atPath: manifestURL.path)
            && fileManager.fileExists(atPath: configURL.path)
            && fileManager.fileExists(atPath: vocabURL.path)
            && fileManager.fileExists(atPath: jointModelURL.path)
    }
}
