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
        pendingVoiceInstallAfterSharedModel = voice

        if assetLocator.isSharedModelInstalled() {
            pendingVoiceInstallAfterSharedModel = nil
            repairVoiceIfNeeded(voice)
            return
        }

        repairSharedModelIfNeeded()
    }

    func downloadSharedModel() {
        guard installTask == nil else { return }
        activeInstallTarget = .sharedModel

        installTask = Task { [fileManager, session] in
            do {
                Self.log("Shared model install requested.")
                await MainActor.run {
                    self.sharedModelInstallState = .downloading(progress: 0)
                }

                let descriptor = try await PocketTTSModelCatalog.fetchSharedModelDescriptor(session: session)
                try await self.install(
                    descriptor: descriptor,
                    target: .sharedModel,
                    stagingRootURL: try Self.makeStagingRootURL(fileManager: fileManager, target: .sharedModel),
                    finalRootURL: try Self.finalSharedModelRootURL(fileManager: fileManager),
                    progress: { progress in
                        self.sharedModelInstallState = .downloading(progress: progress)
                    },
                    installing: {
                        self.sharedModelInstallState = .installing(progress: 0.95)
                    }
                )

                let manifest = PocketTTSInstallManifest(
                    sourceRepository: PocketTTSModelCatalog.repositoryID,
                    artifactSizesByRelativePath: Dictionary(
                        uniqueKeysWithValues: descriptor.artifacts.map { ($0.relativePath, $0.expectedByteCount) }
                    )
                )
                try Self.writeManifest(
                    manifest,
                    to: try Self.finalSharedManifestRootURL(fileManager: fileManager)
                )

                guard self.assetLocator.isSharedModelInstalled() else {
                    throw NSError(
                        domain: "PocketTTSModelManager",
                        code: 5,
                        userInfo: [NSLocalizedDescriptionKey: "Speak engine install validation failed."]
                    )
                }

                let queuedVoice = self.pendingVoiceInstallAfterSharedModel.flatMap { voice in
                    self.assetLocator.isVoiceInstalled(voice) ? nil : voice
                }

                await MainActor.run {
                    if let queuedVoice {
                        self.voiceInstallStates[queuedVoice] = .downloading(progress: 0)
                        self.activeInstallTarget = .voice(queuedVoice)
                    }
                    self.sharedModelInstallState = .ready
                }
                Self.log("Shared model install completed successfully.")
            } catch {
                Self.log("Shared model install failed with error: \(error.localizedDescription)")
                await MainActor.run {
                    self.sharedModelInstallState = .failed(error.localizedDescription)
                }
                self.pendingVoiceInstallAfterSharedModel = nil
            }

            await self.finishSharedModelInstall(fileManager: fileManager, session: session)
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
        activeInstallTarget = .voice(voice)

        installTask = Task { [fileManager, session] in
            await self.performVoiceInstall(voice, fileManager: fileManager, session: session)

            await MainActor.run {
                self.installTask = nil
                self.activeInstallTarget = nil
            }
        }
    }

    func deleteVoice(_ voice: AppSettingsStore.TTSVoice) {
        onDidInvalidateInstalledAssets?()
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

private extension PocketTTSModelManager {
    func finishSharedModelInstall(
        fileManager: FileManager,
        session: URLSession
    ) async {
        guard assetLocator.isSharedModelInstalled(),
              let pendingVoice = pendingVoiceInstallAfterSharedModel,
              assetLocator.isVoiceInstalled(pendingVoice) == false else {
            pendingVoiceInstallAfterSharedModel = nil
            await MainActor.run {
                self.installTask = nil
                self.activeInstallTarget = nil
            }
            return
        }

        pendingVoiceInstallAfterSharedModel = nil
        await performVoiceInstall(pendingVoice, fileManager: fileManager, session: session)

        await MainActor.run {
            self.installTask = nil
            self.activeInstallTarget = nil
        }
    }

    func performVoiceInstall(
        _ voice: AppSettingsStore.TTSVoice,
        fileManager: FileManager,
        session: URLSession
    ) async {
        do {
            Self.log("Voice install requested for \(voice.rawValue).")
            await MainActor.run {
                self.voiceInstallStates[voice] = .downloading(progress: 0)
            }

            let descriptor = try await PocketTTSModelCatalog.fetchVoiceDescriptor(for: voice, session: session)
            try await self.install(
                descriptor: descriptor,
                target: .voice(voice),
                stagingRootURL: try Self.makeStagingRootURL(fileManager: fileManager, target: .voice(voice)),
                finalRootURL: try Self.finalVoiceRootURL(voice, fileManager: fileManager),
                progress: { progress in
                    self.voiceInstallStates[voice] = .downloading(progress: progress)
                },
                installing: {
                    self.voiceInstallStates[voice] = .installing(progress: 0.95)
                }
            )

            let manifest = PocketTTSInstallManifest(
                sourceRepository: PocketTTSModelCatalog.repositoryID,
                artifactSizesByRelativePath: Dictionary(
                    uniqueKeysWithValues: descriptor.artifacts.map { ($0.relativePath, $0.expectedByteCount) }
                )
            )
            try Self.writeManifest(
                manifest,
                to: try Self.finalVoiceRootURL(voice, fileManager: fileManager)
            )

            guard self.assetLocator.isVoiceInstalled(voice) else {
                throw NSError(
                    domain: "PocketTTSModelManager",
                    code: 8,
                    userInfo: [NSLocalizedDescriptionKey: "\(voice.displayName) voice install validation failed."]
                )
            }

            await MainActor.run {
                self.voiceInstallStates[voice] = .ready
            }
            Self.log("Voice install completed successfully for \(voice.rawValue).")
        } catch {
            Self.log("Voice install failed for \(voice.rawValue) with error: \(error.localizedDescription)")
            await MainActor.run {
                self.voiceInstallStates[voice] = .failed(error.localizedDescription)
            }
        }
    }

    func install(
        descriptor: PocketTTSDescriptor,
        target: PocketTTSInstallTarget,
        stagingRootURL: URL,
        finalRootURL: URL,
        progress: @escaping @MainActor (Double) -> Void,
        installing: @escaping @MainActor () -> Void
    ) async throws {
        Self.log("Fetched descriptor with \(descriptor.artifacts.count) artifacts (\(descriptor.requiredDownloadBytes) bytes).")
        try Self.prepareDirectory(stagingRootURL, fileManager: fileManager)
        Self.log("Prepared staging directory at \(stagingRootURL.path).")

        var completedBytes: Int64 = 0
        let totalBytes = max(descriptor.requiredDownloadBytes, 1)

        for artifact in descriptor.artifacts {
            let destinationURL = stagingRootURL.appendingPathComponent(artifact.relativePath, isDirectory: false)
            try Self.prepareParentDirectory(for: destinationURL, fileManager: fileManager)

            if artifact.expectedByteCount == 0 {
                try Data().write(to: destinationURL, options: [.atomic])
            } else {
                Self.log("Downloading artifact \(artifact.relativePath) from \(artifact.remoteURL.absoluteString).")
                let temporaryURL = try await Self.download(artifact.remoteURL, using: session)
                try Self.replaceItem(at: destinationURL, with: temporaryURL, fileManager: fileManager)
            }

            completedBytes += artifact.expectedByteCount
            let currentProgress = min(max(Double(completedBytes) / Double(totalBytes), 0), 0.92)
            await MainActor.run {
                progress(currentProgress)
            }
        }

        await MainActor.run {
            installing()
        }

        switch target {
        case .sharedModel:
            try Self.replaceDirectory(
                at: finalRootURL,
                with: stagingRootURL.appendingPathComponent("Model", isDirectory: true),
                fileManager: fileManager
            )
        case .voice(let voice):
            let stagedVoiceDirectoryURL = stagingRootURL
                .appendingPathComponent("Voices", isDirectory: true)
                .appendingPathComponent(voice.rawValue, isDirectory: true)
            try Self.replaceDirectory(at: finalRootURL, with: stagedVoiceDirectoryURL, fileManager: fileManager)
        }
    }
}
