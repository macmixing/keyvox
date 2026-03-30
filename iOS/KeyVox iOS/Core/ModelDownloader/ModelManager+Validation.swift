import Foundation

extension ModelManager {
    func validatedState(for modelID: DictationModelID) -> ModelInstallState {
        let descriptor = descriptorProvider(modelID)
        guard let installRootURL = modelLocator.installRootURL(for: modelID),
              let manifestURL = modelLocator.manifestURL(for: modelID) else {
            return .failed(message: "App Group container unavailable.")
        }

        if modelID == .whisperBase {
            _ = modelLocator.resolvedWhisperModelPath()
        }

        let installRootExists = fileManager.fileExists(atPath: installRootURL.path)
        let manifestExists = fileManager.fileExists(atPath: manifestURL.path)
        let artifactExistence = descriptor.artifacts.map { artifact in
            modelLocator.artifactURL(for: modelID, relativePath: artifact.relativePath).map {
                fileManager.fileExists(atPath: $0.path)
            } ?? false
        }

        guard installRootExists || manifestExists || artifactExistence.contains(true) else {
            return .notInstalled
        }

        guard installRootExists else {
            return .failed(message: "Model install is incomplete.")
        }

        guard manifestExists else {
            return .failed(message: "Model install is incomplete.")
        }

        let manifest: DictationModelInstallManifest
        do {
            manifest = try readManifest(from: manifestURL)
        } catch {
            return .failed(message: "Model install manifest is missing or unreadable.")
        }

        guard DictationModelInstallManifest.supportedVersions.contains(manifest.version) else {
            return .failed(message: "Model install manifest version is not supported.")
        }

        for artifact in descriptor.artifacts {
            if artifact.retainedAfterInstall {
                guard let artifactURL = modelLocator.artifactURL(for: modelID, relativePath: artifact.relativePath),
                      fileManager.fileExists(atPath: artifactURL.path) else {
                    return .failed(message: "Model install is incomplete.")
                }
            }

            guard manifest.artifactSHA256ByRelativePath[artifact.relativePath]?.lowercased() == artifact.expectedSHA256.lowercased() else {
                return .failed(message: "Model install manifest does not match the expected artifacts.")
            }
        }

        if modelID == .whisperBase,
           let coreMLDirectoryURL = modelLocator.artifactURL(
                for: .whisperBase,
                relativePath: "ggml-base-encoder.mlmodelc"
           ),
           let structureIssue = Self.validateExtractedCoreMLBundle(at: coreMLDirectoryURL, fileManager: fileManager) {
            return .failed(message: structureIssue)
        }

        return .ready
    }

    func ensureModelsDirectoryExists() throws {
        guard let modelsDirectoryURL = modelLocator.modelsDirectoryURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        if !fileManager.fileExists(atPath: modelsDirectoryURL.path) {
            try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
            Self.debugLog("ensureModelsDirectoryExists: created \(modelsDirectoryURL.path)")
        }
    }

    func ensureEnoughDiskSpace(for modelID: DictationModelID) throws {
        guard let modelsDirectoryURL = modelLocator.modelsDirectoryURL,
              let availableBytes = freeSpaceProvider(modelsDirectoryURL) else {
            return
        }

        let requiredBytes = descriptorProvider(modelID).requiredDownloadBytes
        Self.debugLog("""
        ensureEnoughDiskSpace:
          modelID=\(modelID.rawValue)
          available=\(availableBytes)
          required=\(requiredBytes)
        """)
        guard availableBytes >= requiredBytes else {
            throw ModelInstallError.insufficientDiskSpace(requiredBytes: requiredBytes, availableBytes: availableBytes)
        }
    }

    func preflightDiskSpaceErrorMessage(for modelID: DictationModelID) -> String? {
        guard let modelsDirectoryURL = modelLocator.modelsDirectoryURL,
              let availableBytes = freeSpaceProvider(modelsDirectoryURL) else {
            return nil
        }

        let requiredBytes = descriptorProvider(modelID).requiredDownloadBytes
        guard availableBytes < requiredBytes else {
            return nil
        }

        return ModelInstallError
            .insufficientDiskSpace(requiredBytes: requiredBytes, availableBytes: availableBytes)
            .localizedDescription
    }

    func preflightDiskSpaceErrorMessage() -> String? {
        preflightDiskSpaceErrorMessage(for: .whisperBase)
    }
}
