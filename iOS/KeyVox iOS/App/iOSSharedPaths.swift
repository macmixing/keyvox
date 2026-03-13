import Foundation

nonisolated enum iOSSharedPaths {
    static let appGroupID = "group.com.cueit.keyvox"

    static func appGroupUserDefaults() -> UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func containerURL(fileManager: FileManager = .default) -> URL? {
        fileManager.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func modelFileURL(fileManager: FileManager = .default) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("ggml-base.bin")
    }

    static func modelsDirectoryURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?
            .appendingPathComponent("Models", isDirectory: true)
    }

    static func coreMLEncoderZipURL(fileManager: FileManager = .default) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("ggml-base-encoder.mlmodelc.zip")
    }

    static func coreMLEncoderDirectoryURL(fileManager: FileManager = .default) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
    }

    static func modelDownloadStagingDirectoryURL(fileManager: FileManager = .default) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("DownloadStaging", isDirectory: true)
    }

    static func stagedModelFileURL(fileManager: FileManager = .default) -> URL? {
        modelDownloadStagingDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("ggml-base.bin")
    }

    static func stagedCoreMLEncoderZipURL(fileManager: FileManager = .default) -> URL? {
        modelDownloadStagingDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("ggml-base-encoder.mlmodelc.zip")
    }

    static func modelInstallManifestURL(fileManager: FileManager = .default) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("model-install-manifest.json")
    }

    static func modelDownloadJobURL(fileManager: FileManager = .default) -> URL? {
        modelsDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent("model-download-job.json")
    }

    static func dictionaryBaseDirectoryURL(fileManager: FileManager = .default) -> URL? {
        containerURL(fileManager: fileManager)?
            .appendingPathComponent("KeyVoxCore", isDirectory: true)
    }

    static func fallbackBaseDirectoryURL(fileManager: FileManager = .default) -> URL {
        let appSupportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupportDirectory.appendingPathComponent("KeyVoxFallback", isDirectory: true)
    }
}
