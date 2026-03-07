import Foundation

extension iOSModelManager {
    private func mappedProgress(for phase: iOSModelInstallPhase, fraction: Double) -> Double {
        let clamped = min(max(fraction, 0), 1)
        let range: ClosedRange<Double> = switch phase {
        case .downloadingAssets:
            0.05...0.80
        case .movingFiles:
            0.80...0.84
        case .verifyingGGML:
            0.84...0.89
        case .verifyingCoreMLArchive:
            0.89...0.93
        case .extractingCoreML:
            0.93...0.97
        case .validatingCoreMLBundle:
            0.97...0.995
        case .writingManifest:
            0.995...0.999
        case .warmingModel:
            0.999...1.0
        }

        return range.lowerBound + ((range.upperBound - range.lowerBound) * clamped)
    }

    private func applyPhaseProgress(_ phase: iOSModelInstallPhase, fraction: Double) async {
        let progress = mappedProgress(for: phase, fraction: fraction)
        installState = phase == .downloadingAssets
            ? .downloading(progress: progress, phase: phase)
            : .installing(progress: progress, phase: phase)
        await Task.yield()
    }

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

            await applyPhaseProgress(.downloadingAssets, fraction: 0)
            Self.debugLog("performDownloadModel: downloading GGML + Core ML archive.")
            let progressTracker = iOSModelDownloadAggregateProgress()
            let applyProgress: @MainActor (Double) -> Void = { [weak self] overall in
                guard let self else { return }
                self.installState = .downloading(
                    progress: self.mappedProgress(for: .downloadingAssets, fraction: overall),
                    phase: .downloadingAssets
                )
            }
            let publishProgress: @Sendable () -> Void = {
                Task {
                    let overall = await progressTracker.overallFraction()
                    await applyProgress(overall)
                }
            }
            async let ggmlDownload = download(iOSModelDownloadURLs.ggmlBase) { snapshot in
                Task {
                    await progressTracker.updateGGML(snapshot)
                    publishProgress()
                }
            }
            async let coreMLZipDownload = download(iOSModelDownloadURLs.coreMLZip) { snapshot in
                Task {
                    await progressTracker.updateCoreML(snapshot)
                    publishProgress()
                }
            }

            let ggmlTempURL = try await ggmlDownload
            let coreMLZipTempURL = try await coreMLZipDownload
            await applyPhaseProgress(.movingFiles, fraction: 0)
            Self.debugLog("""
            performDownloadModel: downloads finished
              ggmlTemp=\(ggmlTempURL.path)
              coreMLZipTemp=\(coreMLZipTempURL.path)
            """)

            try moveDownloadedFile(from: ggmlTempURL, to: paths.ggmlModelURL)
            try moveDownloadedFile(from: coreMLZipTempURL, to: paths.coreMLZipURL)
            await applyPhaseProgress(.movingFiles, fraction: 1)
            Self.debugLog("performDownloadModel: moved downloaded files into Models/.")

            let ggmlSHA256 = try Self.sha256Hex(forFileAt: paths.ggmlModelURL) { [weak self] completed, total in
                guard let self else { return }
                Task { @MainActor in
                    let fraction = total > 0 ? Double(completed) / Double(total) : 1
                    await self.applyPhaseProgress(.verifyingGGML, fraction: fraction)
                }
            }
            Self.debugLog("""
            performDownloadModel: ggml hash
              actual=\(ggmlSHA256)
              expected=\(expectedGGMLSHA256)
            """)
            guard ggmlSHA256 == expectedGGMLSHA256 else {
                throw ModelInstallError.integrityCheckFailed("ggml-base.bin did not match the expected SHA-256.")
            }

            let coreMLZipSHA256 = try Self.sha256Hex(forFileAt: paths.coreMLZipURL) { [weak self] completed, total in
                guard let self else { return }
                Task { @MainActor in
                    let fraction = total > 0 ? Double(completed) / Double(total) : 1
                    await self.applyPhaseProgress(.verifyingCoreMLArchive, fraction: fraction)
                }
            }
            Self.debugLog("""
            performDownloadModel: coreml zip hash
              actual=\(coreMLZipSHA256)
              expected=\(expectedCoreMLZipSHA256)
            """)
            guard coreMLZipSHA256 == expectedCoreMLZipSHA256 else {
                throw ModelInstallError.integrityCheckFailed("The Core ML archive did not match the expected SHA-256.")
            }

            await applyPhaseProgress(.extractingCoreML, fraction: 0)
            Self.debugLog("performDownloadModel: extracting Core ML archive.")
            try await unzip(paths.coreMLZipURL, paths.modelsDirectory, fileManager) { [weak self] completed, total in
                guard let self else { return }
                Task { @MainActor in
                    let fraction = total > 0 ? Double(completed) / Double(total) : 1
                    await self.applyPhaseProgress(.extractingCoreML, fraction: fraction)
                }
            }

            let coreMLDirectoryDigest = try Self.directoryDigestHex(
                at: paths.coreMLDirectoryURL,
                fileManager: fileManager
            ) { [weak self] completed, total in
                guard let self else { return }
                Task { @MainActor in
                    let fraction = total > 0 ? Double(completed) / Double(total) : 1
                    await self.applyPhaseProgress(.validatingCoreMLBundle, fraction: fraction)
                }
            }
            if let structureIssue = Self.validateExtractedCoreMLBundle(at: paths.coreMLDirectoryURL, fileManager: fileManager) {
                throw ModelInstallError.integrityCheckFailed(structureIssue)
            }
            Self.debugLog("""
            performDownloadModel: coreml directory digest
              actual=\(coreMLDirectoryDigest)
            """)

            try removeItemIfExists(at: paths.coreMLZipURL)
            await applyPhaseProgress(.writingManifest, fraction: 0)
            Self.debugLog("performDownloadModel: removed Core ML zip after successful extraction.")

            let manifest = iOSModelInstallManifest(
                version: iOSModelInstallManifest.currentVersion,
                ggmlSHA256: ggmlSHA256,
                coreMLZipSHA256: coreMLZipSHA256
            )
            try writeManifest(manifest, to: paths.manifestURL)
            await applyPhaseProgress(.writingManifest, fraction: 1)
            Self.debugLog("performDownloadModel: wrote install manifest.")

            let validation = validateInstall(paths: paths)
            Self.debugLog("performDownloadModel: post-install validation = \(validation.debugDescription)")
            switch validation {
            case .ready:
                await applyPhaseProgress(.warmingModel, fraction: 0)
                whisperService.unloadModel()
                whisperService.warmup()
                await applyPhaseProgress(.warmingModel, fraction: 1)
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
