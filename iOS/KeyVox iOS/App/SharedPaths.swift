import Foundation

nonisolated enum SharedPaths {
    static let appGroupID = "group.com.cueit.keyvox"

    static func appGroupUserDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func containerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func modelDirectoryURL(
        for modelID: DictationModelID,
        fileManager: FileManager = .default
    ) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(modelID.installDirectoryName, isDirectory: true)
    }

    static func modelArtifactURL(
        modelID: DictationModelID,
        relativePath: String,
        fileManager: FileManager = .default
    ) -> URL? {
        guard var url = modelDirectoryURL(for: modelID, fileManager: fileManager) else {
            return nil
        }

        for component in relativePath.split(separator: "/") {
            url.appendPathComponent(String(component), isDirectory: false)
        }

        return url
    }

    static func modelInstallManifestURL(
        for modelID: DictationModelID,
        fileManager: FileManager = .default
    ) -> URL? {
        modelDirectoryURL(for: modelID, fileManager: fileManager)?
            .appendingPathComponent(DictationModelCatalog.manifestFilename)
    }

    static func modelDownloadStagingDirectoryURL(
        for modelID: DictationModelID,
        fileManager: FileManager = .default
    ) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(".staging", isDirectory: true)
            .appendingPathComponent(modelID.rawValue, isDirectory: true)
    }

    static func stagedArtifactURL(
        modelID: DictationModelID,
        relativePath: String,
        fileManager: FileManager = .default
    ) -> URL? {
        guard var url = modelDownloadStagingDirectoryURL(for: modelID, fileManager: fileManager) else {
            return nil
        }

        for component in relativePath.split(separator: "/") {
            url.appendPathComponent(String(component), isDirectory: false)
        }

        return url
    }

    static func modelFileURL(fileManager: FileManager = .default) -> URL? {
        modelArtifactURL(modelID: .whisperBase, relativePath: "ggml-base.bin", fileManager: fileManager)
    }

    static func modelsDirectoryURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?
            .appendingPathComponent("Models", isDirectory: true)
    }

    static func coreMLEncoderZipURL(fileManager: FileManager = .default) -> URL? {
        modelArtifactURL(
            modelID: .whisperBase,
            relativePath: "ggml-base-encoder.mlmodelc.zip",
            fileManager: fileManager
        )
    }

    static func coreMLEncoderDirectoryURL(fileManager: FileManager = .default) -> URL? {
        modelArtifactURL(
            modelID: .whisperBase,
            relativePath: "ggml-base-encoder.mlmodelc",
            fileManager: fileManager
        )
    }

    static func modelDownloadStagingDirectoryURL(fileManager: FileManager = .default) -> URL? {
        modelDownloadStagingDirectoryURL(for: .whisperBase, fileManager: fileManager)
    }

    static func stagedModelFileURL(fileManager: FileManager = .default) -> URL? {
        stagedArtifactURL(modelID: .whisperBase, relativePath: "ggml-base.bin", fileManager: fileManager)
    }

    static func stagedCoreMLEncoderZipURL(fileManager: FileManager = .default) -> URL? {
        stagedArtifactURL(
            modelID: .whisperBase,
            relativePath: "ggml-base-encoder.mlmodelc.zip",
            fileManager: fileManager
        )
    }

    static func modelInstallManifestURL(fileManager: FileManager = .default) -> URL? {
        modelInstallManifestURL(for: .whisperBase, fileManager: fileManager)
    }

    static func modelDownloadJobURL(fileManager: FileManager = .default) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("model-download-job.json")
    }

    static func dictionaryBaseDirectoryURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?
            .appendingPathComponent("KeyVoxCore", isDirectory: true)
    }

    static func interruptedCaptureRecoveryDirectoryURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?
            .appendingPathComponent("InterruptedCapture", isDirectory: true)
    }

    static func interruptedCaptureRecoveryURL(fileManager: FileManager = .default) -> URL? {
        interruptedCaptureRecoveryDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("pending-interrupted-capture.plist")
    }

    static func ttsDirectoryURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?
            .appendingPathComponent("TTS", isDirectory: true)
    }

    static func pocketTTSRootDirectoryURL(fileManager: FileManager = .default) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("tts", isDirectory: true)
            .appendingPathComponent("pockettts", isDirectory: true)
    }

    static func pocketTTSModelDirectoryURL(fileManager: FileManager = .default) -> URL? {
        pocketTTSRootDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("Model", isDirectory: true)
    }

    static func pocketTTSVoiceDirectoryURL(fileManager: FileManager = .default) -> URL? {
        pocketTTSRootDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("Voices", isDirectory: true)
    }

    static func ttsRequestURL(fileManager: FileManager = .default) -> URL? {
        ttsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("request.json", isDirectory: false)
    }

    static func fallbackBaseDirectoryURL(fileManager: FileManager = .default) -> URL {
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupportDirectory.appendingPathComponent("KeyVoxFallback", isDirectory: true)
    }
}
