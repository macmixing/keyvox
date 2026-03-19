import Foundation

enum KeyboardModelAvailability {
    static func isInstalled(fileManager: FileManager = .default) -> Bool {
        guard let containerURL = fileManager.containerURL(
            forSecurityApplicationGroupIdentifier: KeyVoxIPCBridge.appGroupID
        ) else {
            return false
        }

        let modelsDirectory = containerURL.appendingPathComponent("Models", isDirectory: true)
        let ggmlModelURL = modelsDirectory.appendingPathComponent("ggml-base.bin", isDirectory: false)
        let coreMLDirectoryURL = modelsDirectory.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
        let coreMLZipURL = modelsDirectory.appendingPathComponent("ggml-base-encoder.mlmodelc.zip", isDirectory: false)
        let manifestURL = modelsDirectory.appendingPathComponent("model-install-manifest.json", isDirectory: false)

        return fileManager.fileExists(atPath: ggmlModelURL.path)
            && fileManager.fileExists(atPath: coreMLDirectoryURL.path)
            && !fileManager.fileExists(atPath: coreMLZipURL.path)
            && fileManager.fileExists(atPath: manifestURL.path)
    }
}
