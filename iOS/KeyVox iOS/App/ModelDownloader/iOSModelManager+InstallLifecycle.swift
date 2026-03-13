import Foundation

extension iOSModelManager {
    private func mappedProgress(for phase: iOSModelInstallPhase, fraction: Double) -> Double {
        let clamped = min(max(fraction, 0), 1)
        let range: ClosedRange<Double> = switch phase {
        case .downloadingAssets:
            0.05...0.80
        case .resumingInstall, .movingFiles:
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

    private func backgroundJobStore() -> iOSModelBackgroundDownloadJobStore {
        iOSModelBackgroundDownloadJobStore(
            fileManager: fileManager,
            jobURLProvider: modelDownloadJobURLProvider
        )
    }

    func persistedBackgroundDownloadJob() -> iOSModelBackgroundDownloadJob? {
        backgroundJobStore().load()
    }

    func applyBackgroundJobStatus(_ job: iOSModelBackgroundDownloadJob) {
        if let message = job.lastErrorMessage,
           job.finalizationState == .failed {
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
            return
        }

        if job.isReadyForFinalization || job.finalizationState == .inProgress {
            modelReady = false
            installState = .installing(
                progress: mappedProgress(for: .resumingInstall, fraction: 0.25),
                phase: .resumingInstall
            )
            errorMessage = nil
            return
        }

        if job.hasActiveDownload || job.finalizationState == .awaitingDownloads {
            modelReady = false
            installState = .downloading(
                progress: mappedProgress(for: .downloadingAssets, fraction: job.downloadProgressFraction),
                phase: .downloadingAssets
            )
            errorMessage = nil
            return
        }

        if let message = job.lastErrorMessage {
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
            return
        }

        modelReady = false
        installState = .downloading(
            progress: mappedProgress(for: .downloadingAssets, fraction: job.downloadProgressFraction),
            phase: .downloadingAssets
        )
        errorMessage = nil
    }

    func startOrResumeDownloadJob() async {
        defer { currentDownloadTask = nil }
        errorMessage = nil

        guard let paths = resolvedPaths() else {
            Self.debugLog("startOrResumeDownloadJob: App Group container unavailable.")
            installState = .failed(message: "App Group container unavailable.")
            errorMessage = "App Group container unavailable."
            modelReady = false
            return
        }

        guard let backgroundDownloadCoordinator else {
            await performDownloadModel()
            return
        }

        do {
            try ensureModelsDirectoryExists(paths.modelsDirectory)
            try ensureEnoughDiskSpace(in: paths.modelsDirectory)
            _ = try await backgroundDownloadCoordinator.startOrResumeJob()
            refreshStatus()
            await resumeForegroundFinalizationIfNeeded()
        } catch {
            let message = Self.userFacingErrorMessage(for: error)
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
            backgroundDownloadCoordinator.markFinalizationFailed(message: message)
            iOSModelDownloadBackgroundTasks.scheduleRepairIfNeeded()
        }
    }

    func resumeForegroundFinalizationIfNeeded() async {
        guard appIsActive,
              !isFinalizationInFlight,
              let backgroundDownloadCoordinator,
              let job = persistedBackgroundDownloadJob(),
              job.isReadyForFinalization else {
            return
        }

        guard let stagedGGMLURL = stagedGGMLURLProvider(),
              let stagedCoreMLZipURL = stagedCoreMLZipURLProvider(),
              let paths = resolvedPaths() else {
            return
        }

        isFinalizationInFlight = true
        backgroundDownloadCoordinator.markFinalizationInProgress()
        defer { isFinalizationInFlight = false }

        do {
            await applyPhaseProgress(.resumingInstall, fraction: 0)
            try await finalizeDownloadedArtifacts(
                stagedGGMLURL: stagedGGMLURL,
                stagedCoreMLZipURL: stagedCoreMLZipURL,
                paths: paths
            )
            await backgroundDownloadCoordinator.clearJob()
            refreshStatus()
        } catch {
            let message = Self.userFacingErrorMessage(for: error)
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
            backgroundDownloadCoordinator.markFinalizationFailed(message: message)
            iOSModelDownloadBackgroundTasks.scheduleRepairIfNeeded()
        }
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
            try await finalizeDownloadedArtifacts(
                stagedGGMLURL: ggmlTempURL,
                stagedCoreMLZipURL: coreMLZipTempURL,
                paths: paths
            )
        } catch {
            let message = Self.userFacingErrorMessage(for: error)
            Self.debugLog("performDownloadModel: failed with error: \(message)")
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
            iOSModelDownloadBackgroundTasks.scheduleRepairIfNeeded()
        }
    }

    private func finalizeDownloadedArtifacts(
        stagedGGMLURL: URL,
        stagedCoreMLZipURL: URL,
        paths: ResolvedPaths
    ) async throws {
        await applyPhaseProgress(.movingFiles, fraction: 0)
        try moveDownloadedFile(from: stagedGGMLURL, to: paths.ggmlModelURL)
        try moveDownloadedFile(from: stagedCoreMLZipURL, to: paths.coreMLZipURL)
        await applyPhaseProgress(.movingFiles, fraction: 1)

        let ggmlSHA256 = try Self.sha256Hex(forFileAt: paths.ggmlModelURL) { [weak self] completed, total in
            guard let self else { return }
            Task { @MainActor in
                let fraction = total > 0 ? Double(completed) / Double(total) : 1
                await self.applyPhaseProgress(.verifyingGGML, fraction: fraction)
            }
        }
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
        guard coreMLZipSHA256 == expectedCoreMLZipSHA256 else {
            throw ModelInstallError.integrityCheckFailed("The Core ML archive did not match the expected SHA-256.")
        }

        await applyPhaseProgress(.extractingCoreML, fraction: 0)
        try await unzip(paths.coreMLZipURL, paths.modelsDirectory, fileManager) { [weak self] completed, total in
            guard let self else { return }
            Task { @MainActor in
                let fraction = total > 0 ? Double(completed) / Double(total) : 1
                await self.applyPhaseProgress(.extractingCoreML, fraction: fraction)
            }
        }

        _ = try Self.directoryDigestHex(
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

        try removeItemIfExists(at: paths.coreMLZipURL)
        await applyPhaseProgress(.writingManifest, fraction: 0)

        let manifest = iOSModelInstallManifest(
            version: iOSModelInstallManifest.currentVersion,
            ggmlSHA256: ggmlSHA256,
            coreMLZipSHA256: coreMLZipSHA256
        )
        try writeManifest(manifest, to: paths.manifestURL)
        await applyPhaseProgress(.writingManifest, fraction: 1)

        let validation = validateInstall(paths: paths)
        switch validation {
        case .ready:
            await applyPhaseProgress(.warmingModel, fraction: 0)
            whisperService.unloadModel()
            whisperService.warmup()
            await applyPhaseProgress(.warmingModel, fraction: 1)
            modelReady = true
            installState = .ready
            errorMessage = nil
        case .notInstalled:
            modelReady = false
            installState = .failed(message: "Model install is incomplete.")
            errorMessage = "Model install is incomplete."
        case .failed(let message):
            modelReady = false
            installState = .failed(message: message)
            errorMessage = message
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

        whisperService.unloadModel()
        try? removeItemIfExists(at: paths.ggmlModelURL)
        try? removeItemIfExists(at: paths.coreMLDirectoryURL)
        try? removeItemIfExists(at: paths.coreMLZipURL)
        try? removeItemIfExists(at: paths.manifestURL)
        if let stagedGGMLURL = stagedGGMLURLProvider() {
            try? removeItemIfExists(at: stagedGGMLURL)
        }
        if let stagedCoreMLZipURL = stagedCoreMLZipURLProvider() {
            try? removeItemIfExists(at: stagedCoreMLZipURL)
        }
        if let stagingDirectoryURL = iOSSharedPaths.modelDownloadStagingDirectoryURL(fileManager: fileManager) {
            try? removeItemIfExists(at: stagingDirectoryURL)
        }
        try? backgroundJobStore().clear()

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
        switch validation {
        case .ready:
            return
        case .notInstalled, .failed:
            try? removeItemIfExists(at: paths.ggmlModelURL)
            try? removeItemIfExists(at: paths.coreMLDirectoryURL)
            try? removeItemIfExists(at: paths.coreMLZipURL)
            try? removeItemIfExists(at: paths.manifestURL)
            if backgroundDownloadCoordinator != nil {
                await startOrResumeDownloadJob()
            } else {
                await performDownloadModel()
            }
        }
    }
}
