import Foundation

struct InstalledDictationModelLocator {
    let fileManager: FileManager
    let modelsDirectoryURL: URL?

    init(
        fileManager: FileManager = .default,
        modelsDirectoryURL: URL? = SharedPaths.modelsDirectoryURL(fileManager: .default)
    ) {
        self.fileManager = fileManager
        self.modelsDirectoryURL = modelsDirectoryURL
    }

    func installRootURL(for modelID: DictationModelID) -> URL? {
        modelsDirectoryURL?
            .appendingPathComponent(modelID.installDirectoryName, isDirectory: true)
    }

    func manifestURL(for modelID: DictationModelID) -> URL? {
        installRootURL(for: modelID)?
            .appendingPathComponent(DictationModelCatalog.manifestFilename)
    }

    func artifactURL(for modelID: DictationModelID, relativePath: String) -> URL? {
        guard var url = installRootURL(for: modelID) else {
            return nil
        }

        for component in relativePath.split(separator: "/") {
            url.appendPathComponent(String(component), isDirectory: false)
        }

        return url
    }

    func stagedRootURL(for modelID: DictationModelID) -> URL? {
        modelsDirectoryURL?
            .appendingPathComponent(".staging", isDirectory: true)
            .appendingPathComponent(modelID.rawValue, isDirectory: true)
    }

    func stagedArtifactURL(for modelID: DictationModelID, relativePath: String) -> URL? {
        guard var url = stagedRootURL(for: modelID) else {
            return nil
        }

        for component in relativePath.split(separator: "/") {
            url.appendPathComponent(String(component), isDirectory: false)
        }

        return url
    }

    func resolvedWhisperModelPath() -> String? {
        guard let installRootURL = resolvedInstallRootURL(for: .whisperBase) else {
            return nil
        }

        let modelURL = installRootURL.appendingPathComponent("ggml-base.bin")
        let encoderBundleURL = installRootURL.appendingPathComponent(
            "ggml-base-encoder.mlmodelc",
            isDirectory: true
        )
        guard fileManager.fileExists(atPath: modelURL.path),
              fileManager.fileExists(atPath: encoderBundleURL.path) else {
            return nil
        }

        return modelURL.path
    }

    func resolvedParakeetModelDirectoryURL() -> URL? {
        resolvedInstallRootURL(for: .parakeetTdtV3)
    }

    func resolvedInstallRootURL(for modelID: DictationModelID) -> URL? {
        if modelID == .whisperBase {
            migrateLegacyWhisperInstallIfNeeded()
        }

        let descriptor = DictationModelCatalog.descriptor(for: modelID)
        guard let installRootURL = installRootURL(for: modelID),
              let manifestURL = manifestURL(for: modelID),
              fileManager.fileExists(atPath: installRootURL.path),
              fileManager.fileExists(atPath: manifestURL.path),
              let manifest = try? readManifest(from: manifestURL),
              DictationModelInstallManifest.supportedVersions.contains(manifest.version) else {
            return nil
        }

        for artifact in descriptor.artifacts {
            if artifact.retainedAfterInstall {
                guard let artifactURL = artifactURL(for: modelID, relativePath: artifact.relativePath),
                      fileManager.fileExists(atPath: artifactURL.path) else {
                    return nil
                }
            }

            guard manifest.artifactSHA256ByRelativePath[artifact.relativePath]?.lowercased() == artifact.expectedSHA256.lowercased() else {
                return nil
            }
        }

        return installRootURL
    }

    private func migrateLegacyWhisperInstallIfNeeded() {
        guard let modelsDirectoryURL,
              let whisperRootURL = installRootURL(for: .whisperBase) else {
            return
        }

        let legacyPairs: [(source: URL, destination: URL)] = [
            (
                modelsDirectoryURL.appendingPathComponent("ggml-base.bin"),
                whisperRootURL.appendingPathComponent("ggml-base.bin")
            ),
            (
                modelsDirectoryURL.appendingPathComponent("ggml-base-encoder.mlmodelc.zip"),
                whisperRootURL.appendingPathComponent("ggml-base-encoder.mlmodelc.zip")
            ),
            (
                modelsDirectoryURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true),
                whisperRootURL.appendingPathComponent("ggml-base-encoder.mlmodelc", isDirectory: true)
            ),
            (
                modelsDirectoryURL.appendingPathComponent("model-install-manifest.json"),
                whisperRootURL.appendingPathComponent(DictationModelCatalog.manifestFilename)
            )
        ]

        let hasLegacyArtifacts = legacyPairs.contains { pair in
            fileManager.fileExists(atPath: pair.source.path)
        }

        guard hasLegacyArtifacts else { return }

        try? fileManager.createDirectory(at: whisperRootURL, withIntermediateDirectories: true)

        for pair in legacyPairs {
            guard fileManager.fileExists(atPath: pair.source.path),
                  !fileManager.fileExists(atPath: pair.destination.path) else {
                continue
            }

            let destinationDirectory = pair.destination.deletingLastPathComponent()
            try? fileManager.createDirectory(at: destinationDirectory, withIntermediateDirectories: true)
            try? fileManager.moveItem(at: pair.source, to: pair.destination)
        }
    }

    private func readManifest(from url: URL) throws -> DictationModelInstallManifest {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(DictationModelInstallManifest.self, from: data)
    }
}
