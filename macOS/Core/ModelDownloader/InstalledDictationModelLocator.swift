import Foundation

struct InstalledDictationModelLocator {
    let fileManager: FileManager
    let appSupportRootURL: URL

    var modelsRootURL: URL {
        appSupportRootURL.appendingPathComponent("Models", isDirectory: true)
    }

    var whisperModelDirectoryURL: URL {
        modelsRootURL.appendingPathComponent("whisper", isDirectory: true)
    }

    var whisperModelURL: URL {
        whisperModelDirectoryURL.appendingPathComponent("ggml-base.bin")
    }

    var legacyWhisperModelURL: URL {
        modelsRootURL.appendingPathComponent("ggml-base.bin")
    }

    var whisperCoreMLModelDirectoryURL: URL {
        whisperModelDirectoryURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
    }

    var legacyWhisperCoreMLModelDirectoryURL: URL {
        modelsRootURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
    }

    var parakeetModelDirectoryURL: URL {
        installRootURL(for: .parakeetTdtV3)
    }

    var downloadStagingRootURL: URL {
        modelsRootURL.appendingPathComponent(".staging", isDirectory: true)
    }

    func resolvedWhisperModelPath() -> String? {
        try? migrateLegacyWhisperInstallIfNeeded()
        return resolvedInstallRootURL(for: .whisperBase)?.path
    }

    func resolvedParakeetModelDirectoryURL() -> URL? {
        resolvedInstallRootURL(for: .parakeetTdtV3)
    }

    func descriptor(for modelID: DictationModelID) -> DictationModelDescriptor {
        DictationModelCatalog.descriptor(for: modelID)
    }

    func installRootURL(for modelID: DictationModelID) -> URL {
        switch descriptor(for: modelID).installLayout {
        case .legacyWhisperBase:
            return whisperModelURL
        case .subdirectory(let name):
            return modelsRootURL.appendingPathComponent(name, isDirectory: true)
        }
    }

    func stagingRootURL(for modelID: DictationModelID) -> URL {
        downloadStagingRootURL.appendingPathComponent(modelID.rawValue, isDirectory: true)
    }

    func manifestURL(for modelID: DictationModelID) -> URL? {
        guard let manifestFilename = descriptor(for: modelID).manifestFilename else {
            return nil
        }

        return installRootURL(for: modelID).appendingPathComponent(manifestFilename, isDirectory: false)
    }

    func installedArtifactURL(for modelID: DictationModelID, relativePath: String) -> URL {
        artifactURL(rootURL: installRootURL(for: modelID), relativePath: relativePath)
    }

    func stagedArtifactURL(for modelID: DictationModelID, relativePath: String) -> URL {
        artifactURL(rootURL: stagingRootURL(for: modelID), relativePath: relativePath)
    }

    func resolvedInstallRootURL(for modelID: DictationModelID) -> URL? {
        let descriptor = descriptor(for: modelID)

        switch descriptor.installLayout {
        case .legacyWhisperBase:
            try? migrateLegacyWhisperInstallIfNeeded()
            return fileManager.fileExists(atPath: whisperModelURL.path) ? whisperModelURL : nil
        case .subdirectory:
            let installRootURL = installRootURL(for: modelID)
            guard fileManager.fileExists(atPath: installRootURL.path) else {
                return nil
            }
            guard let manifestURL = manifestURL(for: modelID),
                  let manifestData = try? Data(contentsOf: manifestURL),
                  let manifest = try? JSONDecoder().decode(DictationModelInstallManifest.self, from: manifestData),
                  DictationModelInstallManifest.supportedVersions.contains(manifest.version) else {
                return nil
            }

            for artifact in descriptor.artifacts {
                let installedURL = installedArtifactURL(for: modelID, relativePath: artifact.relativePath)
                guard fileManager.fileExists(atPath: installedURL.path) else {
                    return nil
                }

                guard manifest.artifactSHA256ByRelativePath[artifact.relativePath]?.lowercased()
                        == artifact.expectedSHA256.lowercased() else {
                    return nil
                }
            }

            return installRootURL
        }
    }

    func migrateLegacyWhisperInstallIfNeeded() throws {
        let hasLegacyBin = fileManager.fileExists(atPath: legacyWhisperModelURL.path)
        let hasLegacyCoreML = fileManager.fileExists(atPath: legacyWhisperCoreMLModelDirectoryURL.path)

        guard hasLegacyBin || hasLegacyCoreML else {
            return
        }

        try fileManager.createDirectory(at: whisperModelDirectoryURL, withIntermediateDirectories: true)

        if hasLegacyBin && !fileManager.fileExists(atPath: whisperModelURL.path) {
            try fileManager.moveItem(at: legacyWhisperModelURL, to: whisperModelURL)
        }

        if hasLegacyCoreML && !fileManager.fileExists(atPath: whisperCoreMLModelDirectoryURL.path) {
            try fileManager.moveItem(at: legacyWhisperCoreMLModelDirectoryURL, to: whisperCoreMLModelDirectoryURL)
        }
    }

    private func artifactURL(rootURL: URL, relativePath: String) -> URL {
        relativePath.split(separator: "/").reduce(rootURL) { url, component in
            url.appendingPathComponent(String(component), isDirectory: false)
        }
    }
}
