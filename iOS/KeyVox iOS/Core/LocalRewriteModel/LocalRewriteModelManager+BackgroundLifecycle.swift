import Foundation

extension LocalRewriteModelManager {
    func downloadModel() {
        guard installTask == nil else { return }
        installTask = Task { [weak self] in
            await self?.startOrRepairDownload()
        }
    }

    func deleteModel() {
        onDidInvalidateInstalledModel?()
        installTask?.cancel()
        installTask = nil
        backgroundDownloadCoordinator.cancelAndClearJob()
        if let finalRootURL = finalRootURL() {
            try? fileManager.removeItem(at: finalRootURL)
        }
        if let stagingRootURL = stagingRootURL() {
            try? fileManager.removeItem(at: stagingRootURL)
        }
        refreshStatus()
    }

    func handleAppDidBecomeActive() {
        appIsActive = true
        Task { [weak self] in
            guard let self else { return }
            await self.backgroundDownloadCoordinator.handleAppDidBecomeActive()
            guard self.appIsActive else { return }
            let job = await self.backgroundDownloadCoordinator.synchronizeWithSystemTasks()
            if let job,
               job.matches(self.descriptor),
               !job.isReadyForFinalization,
               job.finalizationState != .failed {
                try? await self.backgroundDownloadCoordinator.startOrResumeJob(job)
            }
            self.refreshStatus()
            await self.resumeForegroundFinalizationIfNeeded()
        }
    }

    func handleAppWillResignActive() {
        appIsActive = false
        backgroundDownloadCoordinator.handleAppWillResignActive()
    }

    func handleBackgroundURLSessionEvents(
        identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == LocalRewriteBackgroundDownloadCoordinator.sessionIdentifier else {
            completionHandler()
            return
        }
        backgroundDownloadCoordinator.registerBackgroundSessionCompletionHandler(completionHandler)
    }

    func handleBackgroundDownloadStateChanged(_ job: LocalRewriteBackgroundDownloadJob?) async {
        if let job {
            guard backgroundDownloadCoordinator.loadJob()?.id == job.id else {
                refreshStatus()
                return
            }
            applyBackgroundJobState(job)
        } else {
            refreshStatus()
        }
        await resumeForegroundFinalizationIfNeeded()
    }

    func applyBackgroundJobState(_ job: LocalRewriteBackgroundDownloadJob) {
        let state: LocalRewriteModelInstallState
        if job.finalizationState == .failed {
            state = .failed(
                message: job.lastErrorMessage
                    ?? LocalRewriteBackgroundDownloadCoordinator.downloadFailureMessage
            )
        } else if job.isReadyForFinalization || job.finalizationState == .inProgress {
            state = .installing(progress: 0.93)
        } else {
            state = .downloading(progress: min(max(job.downloadProgressFraction * 0.92, 0), 0.92))
        }
        setState(state)
    }

    func resumeForegroundFinalizationIfNeeded() async {
        guard appIsActive,
              !isFinalizationInFlight,
              let job = backgroundDownloadCoordinator.loadJob(),
              job.isReadyForFinalization else {
            return
        }

        isFinalizationInFlight = true
        backgroundDownloadCoordinator.markFinalizationInProgress()
        defer { isFinalizationInFlight = false }

        do {
            try finalizeBackgroundInstall(job)
            if let stagingRootURL = stagingRootURL() {
                try? fileManager.removeItem(at: stagingRootURL)
            }
            await backgroundDownloadCoordinator.clearJob()
            refreshStatus()
        } catch {
            let message = Self.userFacingErrorMessage(for: error)
            backgroundDownloadCoordinator.markFinalizationFailed(message: message)
            setFailure(message)
        }
    }

    private func startOrRepairDownload() async {
        defer { installTask = nil }

        do {
            if let existingJob = backgroundDownloadCoordinator.loadJob(),
               existingJob.matches(descriptor),
               existingJob.finalizationState != .failed {
                try await backgroundDownloadCoordinator.startOrResumeJob(existingJob)
                refreshStatus()
                return
            }

            await backgroundDownloadCoordinator.clearJob()
            guard let stagingRootURL = stagingRootURL() else {
                throw LocalRewriteModelInstallError.appGroupUnavailable
            }
            try prepareCleanDirectory(stagingRootURL)
            let job = LocalRewriteBackgroundDownloadJob(descriptor: descriptor)
            try await backgroundDownloadCoordinator.startOrResumeJob(job)
            refreshStatus()
        } catch is CancellationError {
            setFailure("Vibes model download was cancelled.")
        } catch {
            setFailure(Self.userFacingErrorMessage(for: error))
        }
    }

    private func finalizeBackgroundInstall(_ job: LocalRewriteBackgroundDownloadJob) throws {
        guard job.matches(descriptor),
              let stagingArtifactURL = stagingArtifactURL(),
              let finalRootURL = finalRootURL(),
              let finalArtifactURL = finalArtifactURL(),
              let manifestURL = manifestURL() else {
            throw LocalRewriteModelInstallError.appGroupUnavailable
        }

        setState(.installing(progress: 0.96))
        let installedHash = try sha256Hex(forFileAt: stagingArtifactURL)
        guard installedHash.lowercased() == descriptor.artifact.expectedSHA256.lowercased() else {
            throw LocalRewriteModelInstallError.integrityCheckFailed
        }

        setState(.installing(progress: 0.98))
        try prepareCleanDirectory(finalRootURL)
        try fileManager.moveItem(at: stagingArtifactURL, to: finalArtifactURL)
        let fileSize = try fileSize(at: finalArtifactURL)
        let manifest = LocalRewriteModelInstallManifest(
            modelID: descriptor.id,
            artifactFilename: descriptor.artifact.filename,
            sourceRepository: descriptor.sourceRepository,
            expectedSHA256: descriptor.artifact.expectedSHA256,
            installedSHA256: installedHash,
            fileSize: fileSize,
            installedAt: Date()
        )
        try writeManifest(manifest, to: manifestURL)
        guard isModelReady() else {
            throw LocalRewriteModelInstallError.integrityCheckFailed
        }
        setState(.ready)
    }
}
