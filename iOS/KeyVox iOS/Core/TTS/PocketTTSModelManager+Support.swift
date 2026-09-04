import Foundation

extension PocketTTSModelManager {
    static func finalSharedModelRootURL(fileManager: FileManager) throws -> URL {
        guard let rootURL = SharedPaths.pocketTTSModelDirectoryURL(fileManager: fileManager) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate the Speak engine install directory."]
            )
        }
        return rootURL
    }

    static func finalSharedManifestRootURL(fileManager: FileManager) throws -> URL {
        guard let rootURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate the Speak engine root directory."]
            )
        }
        return rootURL
    }

    static func finalVoiceRootURL(_ voice: AppSettingsStore.TTSVoice, fileManager: FileManager) throws -> URL {
        guard let rootURL = SharedPaths.pocketTTSVoiceDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(voice.rawValue, isDirectory: true) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 9,
                userInfo: [NSLocalizedDescriptionKey: "Unable to locate the \(voice.displayName) voice install directory."]
            )
        }
        return rootURL
    }

    nonisolated static func makeStagingRootURL(
        fileManager: FileManager,
        target: PocketTTSInstallTarget
    ) throws -> URL {
        guard let ttsDirectoryURL = SharedPaths.ttsDirectoryURL(fileManager: fileManager) else {
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "Unable to create the Speak engine staging directory."]
            )
        }

        let stagingComponent: String
        switch target {
        case .sharedModel:
            stagingComponent = "pockettts-model"
        case .voice(let voice):
            stagingComponent = "pockettts-voice-\(voice.rawValue)"
        }

        return ttsDirectoryURL
            .appendingPathComponent("staging", isDirectory: true)
            .appendingPathComponent(stagingComponent, isDirectory: true)
    }

    static func prepareDirectory(_ url: URL, fileManager: FileManager) throws {
        if fileManager.fileExists(atPath: url.path) {
            log("Removing stale staging directory at \(url.path).")
            try fileManager.removeItem(at: url)
        }
        try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
    }

    static func writeManifest(_ manifest: PocketTTSInstallManifest, to rootURL: URL) throws {
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true, attributes: nil)
        let manifestURL = rootURL.appendingPathComponent(PocketTTSInstallManifest.filename, isDirectory: false)
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: manifestURL, options: [.atomic])
    }

    static func replaceDirectory(at destinationURL: URL, with stagingURL: URL, fileManager: FileManager) throws {
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destinationURL.path) {
            log("Removing previous install at \(destinationURL.path).")
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: stagingURL, to: destinationURL)
    }

    static func log(_ message: String) {
        #if DEBUG
        NSLog("[PocketTTSModelManager] %@", message)
        #endif
    }
}
