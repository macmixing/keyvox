import Foundation

extension iOSModelManager {
    func performDownloadModel() async {
        defer { currentDownloadTask = nil }
        errorMessage = nil

        guard let paths = resolvedPaths() else {
            Self.debugLog("performDownloadModel: App Group container unavailable.")
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            modelReady = false
            return
        }

        do {
            Self.debugLog("""
            performDownloadModel: starting
              modelsDirectory=\(paths.modelsDirectory.path)
              ggml=\(paths.ggmlModelURL.path)
              coreMLZip=\(paths.coreMLZipURL.path)
              coreMLDir=\(paths.coreMLDirectoryURL.path)
              manifest=\(paths.manifestURL.path)
            """)
            try ensureModelsDirectoryExists(paths.modelsDirectory)
            try ensureEnoughDiskSpace(in: paths.modelsDirectory)

            installState = .downloading(progress: 0.05)
            Self.debugLog("performDownloadModel: downloading GGML + Core ML archive.")
            async let ggmlDownload = download(iOSModelDownloadURLs.ggmlBase)
            async let coreMLZipDownload = download(iOSModelDownloadURLs.coreMLZip)

            let ggmlTempURL = try await ggmlDownload
            installState = .downloading(progress: 0.5)
            let coreMLZipTempURL = try await coreMLZipDownload
            installState = .downloading(progress: 0.85)
            Self.debugLog("""
            performDownloadModel: downloads finished
              ggmlTemp=\(ggmlTempURL.path)
              coreMLZipTemp=\(coreMLZipTempURL.path)
            """)

            try moveDownloadedFile(from: ggmlTempURL, to: paths.ggmlModelURL)
            try moveDownloadedFile(from: coreMLZipTempURL, to: paths.coreMLZipURL)
            Self.debugLog("performDownloadModel: moved downloaded files into Models/.")

            let ggmlSHA256 = try Self.sha256Hex(forFileAt: paths.ggmlModelURL)
            Self.debugLog("""
            performDownloadModel: ggml hash
              actual=\(ggmlSHA256)
              expected=\(expectedGGMLSHA256)
            """)
            guard ggmlSHA256 == expectedGGMLSHA256 else {
                throw ModelInstallError.integrityCheckFailed("ggml-base.bin did not match the expected SHA-256.")
            }

            let coreMLZipSHA256 = try Self.sha256Hex(forFileAt: paths.coreMLZipURL)
            Self.debugLog("""
            performDownloadModel: coreml zip hash
              actual=\(coreMLZipSHA256)
              expected=\(expectedCoreMLZipSHA256)
            """)
            guard coreMLZipSHA256 == expectedCoreMLZipSHA256 else {
                throw ModelInstallError.integrityCheckFailed("The Core ML archive did not match the expected SHA-256.")
            }

            installState = .installing
            Self.debugLog("performDownloadModel: extracting Core ML archive.")
            try await unzip(paths.coreMLZipURL, paths.modelsDirectory, fileManager)

            let coreMLDirectoryDigest = try Self.directoryDigestHex(at: paths.coreMLDirectoryURL, fileManager: fileManager)
            if let structureIssue = Self.validateExtractedCoreMLBundle(at: paths.coreMLDirectoryURL, fileManager: fileManager) {
                throw ModelInstallError.integrityCheckFailed(structureIssue)
            }
            Self.debugLog("""
            performDownloadModel: coreml directory digest
              actual=\(coreMLDirectoryDigest)
            """)

            try removeItemIfExists(at: paths.coreMLZipURL)
            Self.debugLog("performDownloadModel: removed Core ML zip after successful extraction.")

            let manifest = iOSModelInstallManifest(
                version: iOSModelInstallManifest.currentVersion,
                ggmlSHA256: ggmlSHA256,
                coreMLZipSHA256: coreMLZipSHA256
            )
            try writeManifest(manifest, to: paths.manifestURL)
            Self.debugLog("performDownloadModel: wrote install manifest.")

            let validation = validateInstall(paths: paths)
            Self.debugLog("performDownloadModel: post-install validation = \(validation.debugDescription)")
            switch validation {
            case .ready:
                whisperService.unloadModel()
                whisperService.warmup()
                modelReady = true
                installState = .ready
                errorMessage = nil
                Self.debugLog("performDownloadModel: install complete and whisper warmed.")
            case .notInstalled:
                modelReady = false
                installState = .failed(message: "Model install is incomplete.")
                errorMessage = "Model install is incomplete."
                Self.debugLog("performDownloadModel: validation unexpectedly returned notInstalled.")
            case .failed(let message):
                modelReady = false
                installState = .failed(message: message)
                errorMessage = message
                Self.debugLog("performDownloadModel: validation failed after install: \(message)")
            }
        } catch {
            let message = Self.userFacingErrorMessage(for: error)
            Self.debugLog("performDownloadModel: failed with error: \(message)")
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
            iOSModelDownloadBackgroundTasks.scheduleRepairIfNeeded()
        }
    }

    func performDeleteModel() {
        guard let paths = resolvedPaths() else {
            Self.debugLog("performDeleteModel: App Group container unavailable.")
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            modelReady = false
            return
        }

        Self.debugLog("""
        performDeleteModel:
          ggmlExists=\(fileManager.fileExists(atPath: paths.ggmlModelURL.path))
          coreMLDirExists=\(fileManager.fileExists(atPath: paths.coreMLDirectoryURL.path))
          coreMLZipExists=\(fileManager.fileExists(atPath: paths.coreMLZipURL.path))
          manifestExists=\(fileManager.fileExists(atPath: paths.manifestURL.path))
        """)
        whisperService.unloadModel()
        try? removeItemIfExists(at: paths.ggmlModelURL)
        try? removeItemIfExists(at: paths.coreMLDirectoryURL)
        try? removeItemIfExists(at: paths.coreMLZipURL)
        try? removeItemIfExists(at: paths.manifestURL)

        refreshStatus()
    }

    func performRepairModelIfNeeded() async {
        defer { currentDownloadTask = nil }
        guard let paths = resolvedPaths() else {
            Self.debugLog("performRepairModelIfNeeded: App Group container unavailable.")
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            modelReady = false
            return
        }

        let validation = validateInstall(paths: paths)
        Self.debugLog("performRepairModelIfNeeded: validation = \(validation.debugDescription)")
        switch validation {
        case .ready:
            Self.debugLog("performRepairModelIfNeeded: install already ready, no-op.")
        case .notInstalled, .failed:
            try? removeItemIfExists(at: paths.ggmlModelURL)
            try? removeItemIfExists(at: paths.coreMLDirectoryURL)
            try? removeItemIfExists(at: paths.coreMLZipURL)
            try? removeItemIfExists(at: paths.manifestURL)
            await performDownloadModel()
        }
    }
}
