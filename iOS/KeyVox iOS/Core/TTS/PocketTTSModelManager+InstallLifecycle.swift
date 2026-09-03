import Foundation

extension PocketTTSModelManager {
    func installVoiceEnsuringSharedModel(_ voice: AppSettingsStore.TTSVoice) {
        pendingVoiceInstallAfterSharedModel = voice

        if assetLocator.isSharedModelInstalled() {
            pendingVoiceInstallAfterSharedModel = nil
            if assetLocator.isVoiceInstalled(voice) == false {
                downloadVoice(voice)
            }
            return
        }

        downloadSharedModel()
    }

    func repairVoiceEnsuringSharedModel(_ voice: AppSettingsStore.TTSVoice) {
        if assetLocator.isSharedModelInstalled() {
            repairVoiceIfNeeded(voice)
            return
        }

        deleteSharedModel()
        pendingVoiceInstallAfterSharedModel = voice
        downloadSharedModel()
    }

    func downloadSharedModel() {
        guard installTask == nil else { return }
        if let existingJob = backgroundDownloadCoordinator.loadJob(), existingJob.target != .sharedModel {
            return
        }
        activeInstallTarget = .sharedModel

        installTask = Task { [session] in
            defer {
                installTask = nil
                refreshStatus()
            }

            do {
                Self.log("Shared model install requested.")
                sharedModelInstallState = .downloading(progress: 0)

                if let existingJob = backgroundDownloadCoordinator.loadJob() {
                    try await backgroundDownloadCoordinator.startOrResumeJob(existingJob)
                    return
                }

                let descriptor = try await PocketTTSModelCatalog.fetchSharedModelDescriptor(session: session)
                try await startBackgroundInstall(
                    descriptor: descriptor,
                    target: .sharedModel,
                    queuedVoiceAfterSharedModel: pendingVoiceInstallAfterSharedModel
                )
                pendingVoiceInstallAfterSharedModel = nil
            } catch {
                Self.log("Shared model install failed with error: \(error.localizedDescription)")
                sharedModelInstallState = .failed(error.localizedDescription)
                pendingVoiceInstallAfterSharedModel = nil
            }
        }
    }

    func deleteModel() {
        deleteSharedModel()
    }

    func deleteSharedModel() {
        Self.log("Deleting installed PocketTTS shared model assets.")
        onDidInvalidateInstalledAssets?()
        installTask?.cancel()
        installTask = nil
        backgroundDownloadCoordinator.cancelAndClearJob()
        activeInstallTarget = nil
        pendingVoiceInstallAfterSharedModel = nil

        if let rootURL = SharedPaths.pocketTTSRootDirectoryURL(fileManager: fileManager) {
            try? fileManager.removeItem(at: rootURL)
        }
        refreshStatus()
    }

    func repairModelIfNeeded() {
        repairSharedModelIfNeeded()
    }

    func repairSharedModelIfNeeded() {
        deleteSharedModel()
        downloadSharedModel()
    }

    func downloadVoice(_ voice: AppSettingsStore.TTSVoice) {
        guard installTask == nil else { return }
        if let existingJob = backgroundDownloadCoordinator.loadJob(), existingJob.target != .voice(voice) {
            return
        }
        activeInstallTarget = .voice(voice)

        installTask = Task { [session] in
            defer {
                installTask = nil
                refreshStatus()
            }

            do {
                voiceInstallStates[voice] = .downloading(progress: 0)
                if let existingJob = backgroundDownloadCoordinator.loadJob() {
                    try await backgroundDownloadCoordinator.startOrResumeJob(existingJob)
                    return
                }

                let descriptor = try await PocketTTSModelCatalog.fetchVoiceDescriptor(for: voice, session: session)
                try await startBackgroundInstall(descriptor: descriptor, target: .voice(voice))
            } catch {
                Self.log("Voice install failed for \(voice.rawValue) with error: \(error.localizedDescription)")
                voiceInstallStates[voice] = .failed(error.localizedDescription)
            }
        }
    }

    func deleteVoice(_ voice: AppSettingsStore.TTSVoice) {
        onDidInvalidateInstalledAssets?()
        if backgroundDownloadCoordinator.loadJob()?.target == .voice(voice) {
            backgroundDownloadCoordinator.cancelAndClearJob()
        }
        if let voiceRootURL = SharedPaths.pocketTTSVoiceDirectoryURL(fileManager: fileManager)?
            .appendingPathComponent(voice.rawValue, isDirectory: true) {
            try? fileManager.removeItem(at: voiceRootURL)
        }
        voiceInstallStates[voice] = .notInstalled
        refreshStatus()
    }

    func repairVoiceIfNeeded(_ voice: AppSettingsStore.TTSVoice) {
        deleteVoice(voice)
        downloadVoice(voice)
    }
}
