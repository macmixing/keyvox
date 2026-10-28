import Foundation
import KeyVoxModels

extension PocketTTSModelManager {
    func startBackgroundInstall(
        descriptor: PocketTTSDescriptor,
        target: PocketTTSInstallTarget,
        queuedVoiceAfterSharedModel: AppSettingsStore.TTSVoice? = nil
    ) async throws {
        if let existingJob = backgroundDownloadCoordinator.loadJob() {
            guard existingJob.target == target else {
                throw NSError(
                    domain: "PocketTTSModelManager",
                    code: 11,
                    userInfo: [NSLocalizedDescriptionKey: "Another Speak download is already in progress."]
                )
            }
            try await backgroundDownloadCoordinator.startOrResumeJob(existingJob)
            refreshStatus()
            return
        }

        let stagingRootURL = try Self.makeStagingRootURL(fileManager: fileManager, target: target)
        try Self.prepareDirectory(stagingRootURL, fileManager: fileManager)
        let job = PocketTTSBackgroundDownloadJob(
            target: target,
            descriptor: descriptor,
            queuedVoiceAfterSharedModel: queuedVoiceAfterSharedModel
        )
        try await backgroundDownloadCoordinator.startOrResumeJob(job)
        refreshStatus()
    }

    func handleBackgroundDownloadStateChanged(_ job: PocketTTSBackgroundDownloadJob?) async {
        if let job {
            activeInstallTarget = job.target
            applyBackgroundJobState(job)
        } else {
            refreshStatus()
        }
        await resumeForegroundFinalizationIfNeeded()
    }

    func resumeForegroundFinalizationIfNeeded() async {
        guard appIsActive,
              installTask == nil,
              !isFinalizationInFlight,
              let job = backgroundDownloadCoordinator.loadJob(),
              job.isReadyForFinalization,
              job.finalizationState != .failed else {
            return
        }

        isFinalizationInFlight = true
        backgroundDownloadCoordinator.markFinalizationInProgress()
        defer { isFinalizationInFlight = false }

        do {
            applyInstallState(.installing(progress: 0.95), to: job.target)
            try await finalizeBackgroundInstall(job)
            let queuedVoice = job.queuedVoiceAfterSharedModel
            try? fileManager.removeItem(
                at: Self.makeStagingRootURL(fileManager: fileManager, target: job.target)
            )
            await backgroundDownloadCoordinator.clearJob()
            refreshStatus()

            if job.target == .sharedModel,
               let queuedVoice,
               !assetLocator.isVoiceInstalled(queuedVoice) {
                downloadVoice(queuedVoice)
            }
        } catch is CancellationError {
            Self.log("Background install finalization stopped because its download job was cleared.")
        } catch {
            Self.log("Background install finalization failed with error: \(error.localizedDescription)")
            backgroundDownloadCoordinator.markFinalizationFailed(message: error.localizedDescription)
            applyInstallState(.failed(error.localizedDescription), to: job.target)
        }
    }

    func applyBackgroundJobState(_ job: PocketTTSBackgroundDownloadJob) {
        let state: PocketTTSInstallState
        if job.finalizationState == .failed, let message = job.lastErrorMessage {
            state = .failed(message)
        } else if job.isReadyForFinalization || job.finalizationState == .inProgress {
            state = .installing(progress: 0.95)
        } else {
            state = .downloading(progress: min(max(job.downloadProgressFraction * 0.92, 0), 0.92))
        }
        applyInstallState(state, to: job.target)
    }
}

private extension PocketTTSModelManager {
    func applyInstallState(_ state: PocketTTSInstallState, to target: PocketTTSInstallTarget) {
        switch target {
        case .sharedModel:
            sharedModelInstallState = state
        case .voice(let voice):
            voiceInstallStates[voice] = state
        }
    }

    func verifyStagedArtifacts(of job: PocketTTSBackgroundDownloadJob, stagingRootURL: URL) async throws {
        let stagedArtifacts = try job.artifacts.map { artifact in
            (
                artifact: artifact,
                url: try backgroundDownloadCoordinator.stagedArtifactURL(
                    stagingRootURL: stagingRootURL,
                    relativePath: artifact.relativePath
                )
            )
        }
        let mismatchedArtifact = try await Task.detached(priority: .userInitiated) {
            try stagedArtifacts.first { stagedArtifact in
                try ModelFileIntegrity.sha256Hex(forFileAt: stagedArtifact.url).lowercased()
                    != stagedArtifact.artifact.expectedSHA256.lowercased()
            }
        }.value

        guard backgroundDownloadCoordinator.loadJob()?.id == job.id else {
            throw CancellationError()
        }
        if let mismatchedArtifact {
            Self.log("Artifact hash mismatch for \(mismatchedArtifact.artifact.relativePath).")
            throw NSError(
                domain: "PocketTTSModelManager",
                code: 12,
                userInfo: [NSLocalizedDescriptionKey: "Speak download integrity check failed."]
            )
        }
    }

    func finalizeBackgroundInstall(_ job: PocketTTSBackgroundDownloadJob) async throws {
        let stagingRootURL = try Self.makeStagingRootURL(fileManager: fileManager, target: job.target)
        let manifest = PocketTTSInstallManifest(
            sourceRepository: PocketTTSModelCatalog.repositoryID,
            artifactSizesByRelativePath: Dictionary(
                uniqueKeysWithValues: job.artifacts.map { ($0.relativePath, $0.expectedByteCount) }
            )
        )

        switch job.target {
        case .sharedModel:
            let stagedModelRootURL = stagingRootURL.appendingPathComponent("Model", isDirectory: true)
            let finalModelRootURL = try Self.finalSharedModelRootURL(fileManager: fileManager)
            if fileManager.fileExists(atPath: stagedModelRootURL.path) {
                try await verifyStagedArtifacts(of: job, stagingRootURL: stagingRootURL)
                try Self.replaceDirectory(
                    at: finalModelRootURL,
                    with: stagedModelRootURL,
                    fileManager: fileManager
                )
            } else if !fileManager.fileExists(atPath: finalModelRootURL.path) {
                throw CocoaError(.fileNoSuchFile)
            }
            try Self.writeManifest(
                manifest,
                to: Self.finalSharedManifestRootURL(fileManager: fileManager)
            )
            guard assetLocator.isSharedModelInstalled() else {
                throw NSError(
                    domain: "PocketTTSModelManager",
                    code: 5,
                    userInfo: [NSLocalizedDescriptionKey: "Speak engine install validation failed."]
                )
            }

        case .voice(let voice):
            let stagedVoiceDirectoryURL = stagingRootURL
                .appendingPathComponent("Voices", isDirectory: true)
                .appendingPathComponent(voice.rawValue, isDirectory: true)
            let finalVoiceRootURL = try Self.finalVoiceRootURL(voice, fileManager: fileManager)
            if fileManager.fileExists(atPath: stagedVoiceDirectoryURL.path) {
                try await verifyStagedArtifacts(of: job, stagingRootURL: stagingRootURL)
                try Self.replaceDirectory(
                    at: finalVoiceRootURL,
                    with: stagedVoiceDirectoryURL,
                    fileManager: fileManager
                )
            } else if !fileManager.fileExists(atPath: finalVoiceRootURL.path) {
                throw CocoaError(.fileNoSuchFile)
            }
            try Self.writeManifest(manifest, to: finalVoiceRootURL)
            guard assetLocator.isVoiceInstalled(voice) else {
                throw NSError(
                    domain: "PocketTTSModelManager",
                    code: 8,
                    userInfo: [NSLocalizedDescriptionKey: "\(voice.displayName) voice install validation failed."]
                )
            }
        }
    }
}
