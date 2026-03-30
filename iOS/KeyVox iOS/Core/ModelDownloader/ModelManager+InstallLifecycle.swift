import Foundation
import KeyVoxCore

extension ModelManager {
    private func mappedProgress(for phase: ModelInstallPhase, fraction: Double) -> Double {
        let clamped = min(max(fraction, 0), 1)
        let range: ClosedRange<Double> = switch phase {
        case .downloadingAssets:
            0.05...0.80
        case .resumingInstall, .movingFiles:
            0.80...0.86
        case .verifyingArtifacts:
            0.86...0.92
        case .extractingModelAssets:
            0.92...0.97
        case .validatingInstalledArtifacts:
            0.97...0.995
        case .writingManifest:
            0.995...0.999
        case .warmingModel:
            0.999...1.0
        }

        return range.lowerBound + ((range.upperBound - range.lowerBound) * clamped)
    }

    private func applyPhaseProgress(
        _ phase: ModelInstallPhase,
        fraction: Double,
        for modelID: DictationModelID
    ) async {
        let progress = mappedProgress(for: phase, fraction: fraction)
        let state: ModelInstallState = phase == .downloadingAssets
            ? .downloading(progress: progress, phase: phase)
            : .installing(progress: progress, phase: phase)
        setState(state, for: modelID)
        await Task.yield()
    }

    private func backgroundJobStore() -> ModelBackgroundDownloadJobStore {
        backgroundJobStoreInstance
    }

    func persistedBackgroundDownloadJob() -> ModelBackgroundDownloadJob? {
        backgroundJobStore().load()
    }

    func applyBackgroundJobStatus(_ job: ModelBackgroundDownloadJob) {
        let state: ModelInstallState
        if let message = job.lastErrorMessage, job.finalizationState == .failed {
            state = .failed(message: message)
        } else if job.isReadyForFinalization || job.finalizationState == .inProgress {
            state = .installing(
                progress: mappedProgress(for: .resumingInstall, fraction: 0.25),
                phase: .resumingInstall
            )
        } else if job.hasActiveDownload || job.finalizationState == .awaitingDownloads {
            state = .downloading(
                progress: mappedProgress(for: .downloadingAssets, fraction: job.downloadProgressFraction),
                phase: .downloadingAssets
            )
        } else if let message = job.lastErrorMessage {
            state = .failed(message: message)
        } else {
            state = .downloading(
                progress: mappedProgress(for: .downloadingAssets, fraction: job.downloadProgressFraction),
                phase: .downloadingAssets
            )
        }

        setState(state, for: job.modelID)
    }

    func startOrResumeDownloadJob(for modelID: DictationModelID) async {
        defer { currentDownloadTask = nil }

        guard modelLocator.modelsDirectoryURL != nil else {
            setState(.failed(message: "App Group container unavailable."), for: modelID)
            return
        }

        guard let backgroundDownloadCoordinator else {
            await performDownloadModel(withID: modelID)
            return
        }

        do {
            try ensureModelsDirectoryExists()
            try ensureEnoughDiskSpace(for: modelID)
            _ = try await backgroundDownloadCoordinator.startOrResumeJob(for: modelID)
            refreshStatus()
            await resumeForegroundFinalizationIfNeeded()
        } catch {
            let message = Self.userFacingErrorMessage(for: error)
            setState(.failed(message: message), for: modelID)
            backgroundDownloadCoordinator.markFinalizationFailed(message: message)
            ModelDownloadBackgroundTasks.scheduleRepairIfNeeded()
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

        isFinalizationInFlight = true
        backgroundDownloadCoordinator.markFinalizationInProgress()
        defer { isFinalizationInFlight = false }

        do {
            await applyPhaseProgress(.resumingInstall, fraction: 0, for: job.modelID)
            try await finalizeDownloadedModel(withID: job.modelID)
            await backgroundDownloadCoordinator.clearJob()
            refreshStatus()
        } catch {
            let message = Self.userFacingErrorMessage(for: error)
            setState(.failed(message: message), for: job.modelID)
            backgroundDownloadCoordinator.markFinalizationFailed(message: message)
            ModelDownloadBackgroundTasks.scheduleRepairIfNeeded()
        }
    }

    func performDownloadModel(withID modelID: DictationModelID) async {
        defer { currentDownloadTask = nil }

        guard modelLocator.modelsDirectoryURL != nil else {
            setState(.failed(message: "App Group container unavailable."), for: modelID)
            return
        }

        do {
            try ensureModelsDirectoryExists()
            try ensureEnoughDiskSpace(for: modelID)

            let descriptor = descriptorProvider(modelID)
            await applyPhaseProgress(.downloadingAssets, fraction: 0, for: modelID)
            let progressTracker = ModelDownloadAggregateProgress(artifacts: descriptor.artifacts)
            let applyProgress: @MainActor (Double) -> Void = { [weak self] overall in
                guard let self else { return }
                self.setState(
                    .downloading(
                        progress: self.mappedProgress(for: .downloadingAssets, fraction: overall),
                        phase: .downloadingAssets
                    ),
                    for: modelID
                )
            }

            let downloadedArtifacts = try await withThrowingTaskGroup(
                of: (String, URL).self,
                returning: [String: URL].self
            ) { group in
                for artifact in descriptor.artifacts {
                    group.addTask { [download] in
                        let tempURL = try await download(artifact.remoteURL) { snapshot in
                            Task {
                                await progressTracker.update(snapshot, for: artifact.relativePath)
                                let overall = await progressTracker.overallFraction()
                                await applyProgress(overall)
                            }
                        }
                        return (artifact.relativePath, tempURL)
                    }
                }

                var results: [String: URL] = [:]
                for try await (relativePath, tempURL) in group {
                    results[relativePath] = tempURL
                }
                return results
            }

            try await stageDownloadedArtifacts(downloadedArtifacts, for: modelID)
            try await finalizeDownloadedModel(withID: modelID)
            refreshStatus()
        } catch {
            let message = Self.userFacingErrorMessage(for: error)
            setState(.failed(message: message), for: modelID)
            ModelDownloadBackgroundTasks.scheduleRepairIfNeeded()
        }
    }

    private func stageDownloadedArtifacts(
        _ downloadedArtifacts: [String: URL],
        for modelID: DictationModelID
    ) async throws {
        guard let stagingRootURL = modelLocator.stagedRootURL(for: modelID) else {
            throw CocoaError(.fileNoSuchFile)
        }

        if !fileManager.fileExists(atPath: stagingRootURL.path) {
            try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        }

        for (relativePath, tempURL) in downloadedArtifacts {
            guard let stagedArtifactURL = modelLocator.stagedArtifactURL(for: modelID, relativePath: relativePath) else {
                throw CocoaError(.fileNoSuchFile)
            }

            let parentDirectory = stagedArtifactURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectory.path) {
                try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }

            try moveDownloadedFile(from: tempURL, to: stagedArtifactURL)
        }
    }

    private func finalizeDownloadedModel(withID modelID: DictationModelID) async throws {
        let descriptor = descriptorProvider(modelID)
        guard let installRootURL = modelLocator.installRootURL(for: modelID),
              let manifestURL = modelLocator.manifestURL(for: modelID),
              let stagingRootURL = modelLocator.stagedRootURL(for: modelID) else {
            throw CocoaError(.fileNoSuchFile)
        }

        await applyPhaseProgress(.movingFiles, fraction: 0, for: modelID)
        try removeItemIfExists(at: installRootURL)
        try fileManager.createDirectory(at: installRootURL, withIntermediateDirectories: true)

        for (index, artifact) in descriptor.artifacts.enumerated() {
            guard let stagedArtifactURL = modelLocator.stagedArtifactURL(for: modelID, relativePath: artifact.relativePath),
                  let installedArtifactURL = modelLocator.artifactURL(for: modelID, relativePath: artifact.relativePath) else {
                throw CocoaError(.fileNoSuchFile)
            }

            let parentDirectory = installedArtifactURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectory.path) {
                try fileManager.createDirectory(at: parentDirectory, withIntermediateDirectories: true)
            }

            try moveDownloadedFile(from: stagedArtifactURL, to: installedArtifactURL)
            await applyPhaseProgress(
                .movingFiles,
                fraction: Double(index + 1) / Double(descriptor.artifacts.count),
                for: modelID
            )
        }

        var artifactHashes: [String: String] = [:]
        for (index, artifact) in descriptor.artifacts.enumerated() {
            guard let installedArtifactURL = modelLocator.artifactURL(for: modelID, relativePath: artifact.relativePath) else {
                throw CocoaError(.fileNoSuchFile)
            }

            let hash = try Self.sha256Hex(forFileAt: installedArtifactURL)
            guard hash.lowercased() == artifact.expectedSHA256.lowercased() else {
                throw ModelInstallError.integrityCheckFailed("Downloaded model asset did not match the expected SHA-256.")
            }
            artifactHashes[artifact.relativePath] = hash
            await applyPhaseProgress(
                .verifyingArtifacts,
                fraction: Double(index + 1) / Double(descriptor.artifacts.count),
                for: modelID
            )
        }

        if modelID == .whisperBase,
           let zipURL = modelLocator.artifactURL(for: modelID, relativePath: "ggml-base-encoder.mlmodelc.zip") {
            await applyPhaseProgress(.extractingModelAssets, fraction: 0, for: modelID)
            try await unzip(zipURL, installRootURL, fileManager) { [weak self] completed, total in
                guard let self else { return }
                Task { @MainActor in
                    let fraction = total > 0 ? Double(completed) / Double(total) : 1
                    await self.applyPhaseProgress(.extractingModelAssets, fraction: fraction, for: modelID)
                }
            }
            try removeItemIfExists(at: zipURL)
        }

        await applyPhaseProgress(.validatingInstalledArtifacts, fraction: 0, for: modelID)
        if modelID == .whisperBase,
           let coreMLDirectoryURL = modelLocator.artifactURL(for: modelID, relativePath: "ggml-base-encoder.mlmodelc"),
           let structureIssue = Self.validateExtractedCoreMLBundle(at: coreMLDirectoryURL, fileManager: fileManager) {
            throw ModelInstallError.integrityCheckFailed(structureIssue)
        }
        await applyPhaseProgress(.validatingInstalledArtifacts, fraction: 1, for: modelID)

        await applyPhaseProgress(.writingManifest, fraction: 0, for: modelID)
        let manifest = DictationModelInstallManifest(artifactSHA256ByRelativePath: artifactHashes)
        try writeManifest(manifest, to: manifestURL)
        await applyPhaseProgress(.writingManifest, fraction: 1, for: modelID)

        await applyPhaseProgress(.warmingModel, fraction: 0, for: modelID)
        if let lifecycle = lifecycleProvider(modelID) {
            lifecycle.unloadModel()
            if let parakeetLifecycle = lifecycle as? ParakeetService {
                await parakeetLifecycle.preloadIfNeeded()
            } else {
                lifecycle.warmup()
            }
        }
        await applyPhaseProgress(.warmingModel, fraction: 1, for: modelID)

        try? removeItemIfExists(at: stagingRootURL)
        setState(validatedState(for: modelID), for: modelID)
    }

    func performDeleteModel(withID modelID: DictationModelID) {
        guard modelLocator.modelsDirectoryURL != nil else {
            setState(.failed(message: "App Group container unavailable."), for: modelID)
            return
        }

        lifecycleProvider(modelID)?.unloadModel()
        if let installRootURL = modelLocator.installRootURL(for: modelID) {
            try? removeItemIfExists(at: installRootURL)
        }
        if let stagingRootURL = modelLocator.stagedRootURL(for: modelID) {
            try? removeItemIfExists(at: stagingRootURL)
        }
        if let backgroundJob = persistedBackgroundDownloadJob(), backgroundJob.modelID == modelID {
            try? backgroundJobStore().clear()
        }

        refreshStatus()
    }

    func performRepairModelIfNeeded(for modelID: DictationModelID) async {
        defer { currentDownloadTask = nil }

        let liveState = state(for: modelID)
        switch liveState {
        case .downloading, .installing:
            return
        default:
            break
        }

        if let backgroundJob = persistedBackgroundDownloadJob(),
           backgroundJob.modelID == modelID,
           backgroundJob.finalizationState != .failed {
            return
        }

        switch validatedState(for: modelID) {
        case .ready:
            return
        case .notInstalled, .failed:
            performDeleteModel(withID: modelID)
            if backgroundDownloadCoordinator != nil {
                await startOrResumeDownloadJob(for: modelID)
            } else {
                await performDownloadModel(withID: modelID)
            }
        case .downloading, .installing:
            return
        }
    }
}
