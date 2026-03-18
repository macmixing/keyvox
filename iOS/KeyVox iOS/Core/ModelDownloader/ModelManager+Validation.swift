import Foundation

extension ModelManager {
    func resolvedPaths() -> ResolvedPaths? {
        guard let modelsDirectory = modelsDirectoryProvider(),
              let ggmlModelURL = ggmlModelURLProvider(),
              let coreMLZipURL = coreMLZipURLProvider(),
              let coreMLDirectoryURL = coreMLDirectoryURLProvider(),
              let manifestURL = manifestURLProvider() else {
            return nil
        }

        return ResolvedPaths(
            modelsDirectory: modelsDirectory,
            ggmlModelURL: ggmlModelURL,
            coreMLZipURL: coreMLZipURL,
            coreMLDirectoryURL: coreMLDirectoryURL,
            manifestURL: manifestURL
        )
    }

    func validateInstall(paths: ResolvedPaths) -> InstallValidationResult {
        let ggmlExists = fileManager.fileExists(atPath: paths.ggmlModelURL.path)
        let coreMLDirectoryExists = fileManager.fileExists(atPath: paths.coreMLDirectoryURL.path)
        let coreMLZipExists = fileManager.fileExists(atPath: paths.coreMLZipURL.path)
        let manifestExists = fileManager.fileExists(atPath: paths.manifestURL.path)
        let ggmlSize = fileSizeBytes(at: paths.ggmlModelURL)
        Self.debugLog("""
        validateInstall:
          ggmlExists=\(ggmlExists)
          ggmlSize=\(ggmlSize.map(String.init) ?? "nil")
          minGGMLBytes=\(minGGMLBytes)
          coreMLDirectoryExists=\(coreMLDirectoryExists)
          coreMLZipExists=\(coreMLZipExists)
          manifestExists=\(manifestExists)
        """)

        guard ggmlExists || coreMLDirectoryExists || coreMLZipExists || manifestExists else {
            return .notInstalled
        }

        guard ggmlExists else {
            return .failed(message: "Model install is incomplete. Missing ggml-base.bin.")
        }

        guard let ggmlSize, ggmlSize >= minGGMLBytes else {
            return .failed(message: "Model install is incomplete. ggml-base.bin is missing or undersized.")
        }

        guard coreMLDirectoryExists else {
            return .failed(message: "Model install is incomplete. Missing ggml-base-encoder.mlmodelc.")
        }

        guard !coreMLZipExists else {
            return .failed(message: "Model install is incomplete. Core ML zip cleanup did not finish.")
        }

        guard manifestExists else {
            return .failed(message: "Model install is incomplete. Missing install manifest.")
        }

        do {
            let manifest = try readManifest(from: paths.manifestURL)
            Self.debugLog("""
            validateInstall: manifest
              version=\(manifest.version)
              ggmlSHA=\(manifest.ggmlSHA256)
              coreMLZipSHA=\(manifest.coreMLZipSHA256)
            """)
            guard ModelInstallManifest.supportedVersions.contains(manifest.version) else {
                return .failed(message: "Model install manifest version is not supported.")
            }
            guard manifest.ggmlSHA256 == expectedGGMLSHA256 else {
                return .failed(message: "Model install manifest does not match the expected GGML artifact.")
            }
            guard manifest.coreMLZipSHA256 == expectedCoreMLZipSHA256 else {
                return .failed(message: "Model install manifest does not match the expected Core ML archive.")
            }
            if let structureIssue = Self.validateExtractedCoreMLBundle(at: paths.coreMLDirectoryURL, fileManager: fileManager) {
                return .failed(message: structureIssue)
            }
        } catch {
            return .failed(message: "Model install manifest is missing or unreadable.")
        }

        return .ready
    }

    func ensureModelsDirectoryExists(_ modelsDirectory: URL) throws {
        if !fileManager.fileExists(atPath: modelsDirectory.path) {
            try fileManager.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
            Self.debugLog("ensureModelsDirectoryExists: created \(modelsDirectory.path)")
        }
    }

    func ensureEnoughDiskSpace(in modelsDirectory: URL) throws {
        guard let availableBytes = freeSpaceProvider(modelsDirectory) else { return }
        Self.debugLog("""
        ensureEnoughDiskSpace:
          available=\(availableBytes)
          required=\(requiredDownloadBytes)
        """)
        guard availableBytes >= requiredDownloadBytes else {
            throw ModelInstallError.insufficientDiskSpace(requiredBytes: requiredDownloadBytes, availableBytes: availableBytes)
        }
    }

    func preflightDiskSpaceErrorMessage() -> String? {
        guard let modelsDirectory = modelsDirectoryProvider(),
              let availableBytes = freeSpaceProvider(modelsDirectory),
              availableBytes < requiredDownloadBytes else {
            return nil
        }

        return ModelInstallError
            .insufficientDiskSpace(
                requiredBytes: requiredDownloadBytes,
                availableBytes: availableBytes
            )
            .localizedDescription
    }

    func fileSizeBytes(at url: URL) -> Int64? {
        (try? fileManager.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? nil
    }
}
