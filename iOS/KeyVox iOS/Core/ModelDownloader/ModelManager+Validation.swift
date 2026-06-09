import Foundation

extension ModelManager {
    func requiresArtifactUpdate(for modelID: DictationModelID) -> Bool {
        switch modelID {
        case .parakeetTdtV3:
            return requiresCurrentParakeetArtifacts()
        case .whisperBase:
            return false
        }
    }

    private func requiresCurrentParakeetArtifacts() -> Bool {
#if os(iOS)
        guard ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27,
              let installRootURL = modelLocator.installRootURL(for: .parakeetTdtV3) else {
            return false
        }

        let manifestURL = installRootURL.appendingPathComponent(DictationModelCatalog.manifestFilename, isDirectory: false)
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            return false
        }

        return isLegacyParakeetInstall(at: installRootURL)
#else
        return false
#endif
    }

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

        if modelID == .parakeetTdtV3,
           isLegacyParakeetInstall(at: installRootURL),
           shouldRequireCurrentParakeetArtifacts == false {
            return .ready
        }

        if modelID == .parakeetTdtV3,
           isLegacyParakeetInstall(at: installRootURL),
           shouldRequireCurrentParakeetArtifacts {
            return .failed(message: "This model needs to be updated before dictation can continue.")
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

    private var shouldRequireCurrentParakeetArtifacts: Bool {
#if os(iOS)
        ProcessInfo.processInfo.operatingSystemVersion.majorVersion >= 27
#else
        true
#endif
    }

    private func isLegacyParakeetInstall(at installRootURL: URL) -> Bool {
        let legacyEncoderURL = installRootURL.appendingPathComponent("Encoder.mlmodelc", isDirectory: true)
        let legacyJointURL = installRootURL.appendingPathComponent("JointDecision.mlmodelc", isDirectory: true)
        let legacyJointV2URL = installRootURL.appendingPathComponent("JointDecisionv2.mlmodelc", isDirectory: true)
        let currentEncoderURL = installRootURL.appendingPathComponent("EncoderInt4.mlmodelc", isDirectory: true)
        let currentJointURL = installRootURL.appendingPathComponent("JointDecisionv3.mlmodelc", isDirectory: true)

        let hasLegacyArtifacts = fileManager.fileExists(atPath: legacyEncoderURL.path)
            || fileManager.fileExists(atPath: legacyJointURL.path)
            || fileManager.fileExists(atPath: legacyJointV2URL.path)
        let hasCurrentArtifacts = fileManager.fileExists(atPath: currentEncoderURL.path)
            && fileManager.fileExists(atPath: currentJointURL.path)

        return hasLegacyArtifacts && hasCurrentArtifacts == false
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
