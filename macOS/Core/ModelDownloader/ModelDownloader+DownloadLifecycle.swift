import Foundation
import CryptoKit

extension ModelDownloader {
    func handleDownloadCompletion(task: URLSessionDownloadTask, location: URL) {
        guard let activeDownload else { return }
        guard taskTokensByID[task.taskIdentifier] == activeDownload.token else { return }
        guard let artifact = artifactsByTaskID[task.taskIdentifier] else { return }
        debugLog("Download finished for task \(task.taskIdentifier): \(artifact.relativePath)")

        do {
            switch activeDownload.descriptor.installLayout {
            case .legacyWhisperBase:
                try finalizeWhisperArtifactDownload(artifact: artifact, from: location)
            case .subdirectory:
                try stageStrictManifestArtifact(
                    for: activeDownload.modelID,
                    artifact: artifact,
                    from: location
                )
            }
        } catch {
            handleDownloadFailure(task: task, error: error)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.activeDownload?.modelID == activeDownload.modelID else { return }
            let id = task.taskIdentifier

            self.completedTaskIDs.insert(id)

            if var current = self.taskProgress[id] {
                current.written = max(current.total, current.written)
                self.taskProgress[id] = current
            }

            self.calculateTotalProgress(for: activeDownload.modelID)

            let allDone = self.completedTaskIDs.count == activeDownload.descriptor.artifacts.count
            self.debugLog(
                "Completed \(self.completedTaskIDs.count)/\(activeDownload.descriptor.artifacts.count) artifacts for \(activeDownload.modelID.rawValue)"
            )
            if allDone {
                let completedDownload = activeDownload
                let appSupportRootURL = self.modelLocator.appSupportRootURL
                let modelURL = self.modelURL
                let coreMLZipURL = self.coreMLZipURL
                let minGGMLBytes = self.minGGMLBytes
                self.debugLog("Finalizing install for \(completedDownload.modelID.rawValue)")

                Task { [weak self] in
                    guard let self else { return }

                    do {
                        try await Self.finalizeDownloadedModel(
                            completedDownload,
                            appSupportRootURL: appSupportRootURL,
                            modelURL: modelURL,
                            coreMLZipURL: coreMLZipURL,
                            minGGMLBytes: minGGMLBytes
                        )
                        guard self.activeDownload?.token == completedDownload.token else { return }
                        self.completeSuccessfulDownload(for: completedDownload.modelID)
                    } catch {
                        guard self.activeDownload?.token == completedDownload.token else { return }
                        self.debugLog("Finalization failed for \(completedDownload.modelID.rawValue): \(error)")
                        self.failActiveDownload(
                            for: completedDownload.modelID,
                            message: Self.userFacingErrorMessage(for: error)
                        )
                    }
                }
            }
        }
    }

    func updateTaskProgress(id: Int, written: Int64, total: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let activeDownload = self.activeDownload else { return }
            guard self.taskTokensByID[id] == activeDownload.token else { return }
            let previousTotal = self.taskProgress[id]?.total ?? 0
            let normalizedTotal = total > 0 ? total : max(previousTotal, 1)
            let normalizedWritten = max(written, 0)
            self.taskProgress[id] = (normalizedWritten, normalizedTotal)

            if total <= 0 {
                self.debugLog(
                    "Task \(id) reported unknown total bytes for \(activeDownload.modelID.rawValue); keeping fallback total \(normalizedTotal)"
                )
            }

            self.calculateTotalProgress(for: activeDownload.modelID)
        }
    }

    func handleDownloadFailure(task: URLSessionTask, error: Error) {
        _ = task
        debugLog("Download failed for task \(task.taskIdentifier): \(error)")
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let activeDownload = self.activeDownload else { return }
            guard self.taskTokensByID[task.taskIdentifier] == activeDownload.token else { return }
            self.failActiveDownload(
                for: activeDownload.modelID,
                message: Self.userFacingErrorMessage(for: error)
            )
        }
    }

    private func calculateTotalProgress(for modelID: DictationModelID) {
        guard let activeDownload, activeDownload.modelID == modelID else { return }

        let totalWritten = taskProgress.values.map { $0.written }.reduce(0, +)
        let totalExpected = taskProgress.values.map { $0.total }.reduce(0, +)
        let newProgress: Double

        if totalExpected > 0 {
            newProgress = Double(totalWritten) / Double(totalExpected)
        } else {
            newProgress = 0
        }

        var state = state(for: modelID)
        let clampedProgress = min(max(newProgress, 0), 1)

        state.progress = min(clampedProgress, 0.99)

        updateDownloadState(state, for: modelID)
        syncLegacyWhisperState()
    }

    private func finalizeWhisperArtifactDownload(
        artifact: DictationModelArtifact,
        from location: URL
    ) throws {
        let destinationURL: URL
        if artifact.relativePath == "ggml-base.bin" {
            destinationURL = modelURL
        } else {
            destinationURL = coreMLZipURL
        }

        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: location, to: destinationURL)

        if artifact.relativePath == "ggml-base-encoder.mlmodelc.zip" {
            try unzipCoreML(at: destinationURL)
        }
    }

    private func stageStrictManifestArtifact(
        for modelID: DictationModelID,
        artifact: DictationModelArtifact,
        from location: URL
    ) throws {
        let destinationURL = modelLocator.stagedArtifactURL(for: modelID, relativePath: artifact.relativePath)
        try fileManager.createDirectory(
            at: destinationURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }
        try fileManager.moveItem(at: location, to: destinationURL)
    }

    private static func finalizeDownloadedModel(
        _ activeDownload: ActiveDownload,
        appSupportRootURL: URL,
        modelURL: URL,
        coreMLZipURL: URL,
        minGGMLBytes: Int64
    ) async throws {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let fileManager = FileManager.default
                    let modelLocator = InstalledDictationModelLocator(
                        fileManager: fileManager,
                        appSupportRootURL: appSupportRootURL
                    )

                    switch activeDownload.descriptor.installLayout {
                    case .legacyWhisperBase:
                        guard Self.validateWhisperModelFiles(
                            fileManager: fileManager,
                            modelURL: modelURL,
                            coreMLZipURL: coreMLZipURL,
                            minGGMLBytes: minGGMLBytes
                        ) else {
                            throw NSError(domain: "ModelDownloader", code: 1003)
                        }
                    case .subdirectory:
                        try Self.finalizeStrictManifestModel(
                            activeDownload,
                            fileManager: fileManager,
                            modelLocator: modelLocator
                        )
                    }

                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func finalizeStrictManifestModel(
        _ activeDownload: ActiveDownload,
        fileManager: FileManager,
        modelLocator: InstalledDictationModelLocator
    ) throws {
        var hashes: [String: String] = [:]

        for artifact in activeDownload.descriptor.artifacts {
            let stagedURL = modelLocator.stagedArtifactURL(
                for: activeDownload.modelID,
                relativePath: artifact.relativePath
            )
            guard fileManager.fileExists(atPath: stagedURL.path) else {
                throw NSError(domain: "ModelDownloader", code: 2001)
            }

            let actualHash = try Self.sha256Hex(forFileAt: stagedURL)
            guard actualHash.lowercased() == artifact.expectedSHA256.lowercased() else {
                throw NSError(domain: "ModelDownloader", code: 2002)
            }
            hashes[artifact.relativePath] = actualHash.lowercased()
        }

        guard let manifestFilename = activeDownload.descriptor.manifestFilename else {
            throw NSError(domain: "ModelDownloader", code: 2003)
        }

        let manifest = DictationModelInstallManifest(
            version: DictationModelInstallManifest.currentVersion,
            artifactSHA256ByRelativePath: hashes
        )
        try Self.writeInstallManifest(
            manifest,
            to: modelLocator.stagingRootURL(for: activeDownload.modelID)
                .appendingPathComponent(manifestFilename, isDirectory: false),
            using: fileManager
        )

        let installRootURL = modelLocator.installRootURL(for: activeDownload.modelID)
        let stagingRootURL = modelLocator.stagingRootURL(for: activeDownload.modelID)

        if fileManager.fileExists(atPath: installRootURL.path) {
            try fileManager.removeItem(at: installRootURL)
        }

        try fileManager.createDirectory(
            at: installRootURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try fileManager.moveItem(at: stagingRootURL, to: installRootURL)

        guard modelLocator.strictlyValidatedInstallRootURL(for: activeDownload.modelID) != nil else {
            let validationError = NSError(domain: "ModelDownloader", code: 2004)
            if fileManager.fileExists(atPath: installRootURL.path) {
                try? fileManager.removeItem(at: installRootURL)
            }
            throw validationError
        }
    }

    private static func validateWhisperModelFiles(
        fileManager: FileManager,
        modelURL: URL,
        coreMLZipURL: URL,
        minGGMLBytes: Int64
    ) -> Bool {
        guard fileManager.fileExists(atPath: modelURL.path) else { return false }
        if let attributes = try? fileManager.attributesOfItem(atPath: modelURL.path),
           let size = attributes[.size] as? Int64,
           size < minGGMLBytes {
            return false
        }

        return !fileManager.fileExists(atPath: coreMLZipURL.path)
    }

    private static func writeInstallManifest(
        _ manifest: DictationModelInstallManifest,
        to url: URL,
        using fileManager: FileManager
    ) throws {
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    private static func sha256Hex(forFileAt url: URL) throws -> String {
        let digest = SHA256.hash(data: try Data(contentsOf: url, options: .mappedIfSafe))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func completeSuccessfulDownload(for modelID: DictationModelID) {
        Task { [weak self] in
            guard let self else { return }

            do {
                try await self.postInstallPreparation(modelID)
                DispatchQueue.main.async { [weak self] in
                    guard let self else { return }
                    guard self.activeDownload?.modelID == modelID else { return }
                    self.debugLog("Download completed successfully for \(modelID.rawValue)")
                    var state = self.state(for: modelID)
                    state.isDownloading = false
                    state.progress = 1.0
                    state.errorMessage = nil
                    self.updateDownloadState(state, for: modelID)
                    self.refreshModelStatus()
                    self.finishActiveDownload()
                }
            } catch {
                self.debugLog("Post-install preparation failed for \(modelID.rawValue): \(error)")
                if case .subdirectory = self.modelLocator.descriptor(for: modelID).installLayout {
                    try? self.fileManager.removeItem(at: self.modelLocator.installRootURL(for: modelID))
                }
                self.failActiveDownload(for: modelID, message: Self.userFacingErrorMessage(for: error))
            }
        }
    }

    private func failActiveDownload(for modelID: DictationModelID, message: String) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.failActiveDownload(for: modelID, message: message)
            }
            return
        }

        debugLog("Download failed for \(modelID.rawValue): \(message)")
        var state = state(for: modelID)
        state.isDownloading = false
        state.progress = 0
        state.errorMessage = message
        updateDownloadState(state, for: modelID)

        if case .subdirectory = modelLocator.descriptor(for: modelID).installLayout {
            try? fileManager.removeItem(at: modelLocator.stagingRootURL(for: modelID))
        }

        refreshModelStatus()
        finishActiveDownload()
    }

    private func finishActiveDownload() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.finishActiveDownload()
            }
            return
        }

        taskProgress.removeAll()
        artifactsByTaskID.removeAll()
        taskTokensByID.removeAll()
        completedTaskIDs.removeAll()
        activeDownloadSession = nil
        activeDownload = nil
        syncLegacyWhisperState()
    }

    private func unzipCoreML(at url: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = ["-o", url.path, "-d", url.deletingLastPathComponent().path]

        do {
            try process.run()
            process.waitUntilExit()

            if process.terminationStatus != 0 {
                throw NSError(
                    domain: "ModelDownloader",
                    code: 1002,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to extract model components."]
                )
            }

            // Keep extracted directory authoritative and remove stale zip.
            try fileManager.removeItem(at: url)
        } catch {
            throw error
        }
    }
}
