import Foundation

extension ModelDownloader {
    func handleDownloadCompletion(task: URLSessionDownloadTask, location: URL) {
        guard isDownloading else { return }
        let urlString = task.originalRequest?.url?.absoluteString ?? ""
        let isGGML = urlString.contains("ggml-base.bin")

        do {
            if isGGML {
                if fileManager.fileExists(atPath: modelURL.path) {
                    try fileManager.removeItem(at: modelURL)
                }
                try fileManager.moveItem(at: location, to: modelURL)
            } else {
                let coreMLDest = coreMLZipURL
                if fileManager.fileExists(atPath: coreMLDest.path) {
                    try fileManager.removeItem(at: coreMLDest)
                }
                try fileManager.moveItem(at: location, to: coreMLDest)
                try unzipCoreML(at: coreMLDest)
            }
        } catch {
            handleDownloadFailure(task: task, error: error)
            return
        }

        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isDownloading else { return }
            let id = task.taskIdentifier

            if var current = self.taskProgress[id] {
                current.written = current.total
                self.taskProgress[id] = current
            }

            self.calculateTotalProgress()

            let allDone = self.taskProgress.values.allSatisfy { $0.written >= $0.total && $0.total > 0 }
            if allDone {
                self.isDownloading = false
                self.progress = 1.0
                self.refreshModelStatus() // Update published state
                if !self.modelReady {
                    self.errorMessage = "Model download completed, but validation failed. Please retry the download."
                }
                self.activeDownloadSession = nil
            }
        }
    }

    func updateTaskProgress(id: Int, written: Int64, total: Int64) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isDownloading else { return }
            self.taskProgress[id] = (written, total)
            self.calculateTotalProgress()
        }
    }

    func handleDownloadFailure(task: URLSessionTask, error: Error) {
        _ = task
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard self.isDownloading else { return }

            self.isDownloading = false
            self.progress = 0
            self.taskProgress.removeAll()
            self.activeDownloadSession = nil
            self.errorMessage = Self.userFacingErrorMessage(for: error)
            self.refreshModelStatus()
        }
    }

    private func calculateTotalProgress() {
        let totalWritten = taskProgress.values.map { $0.written }.reduce(0, +)
        let totalExpected = taskProgress.values.map { $0.total }.reduce(0, +)

        if totalExpected > 0 {
            let newProgress = Double(totalWritten) / Double(totalExpected)
            if abs(self.progress - newProgress) > 0.005 {
                self.progress = newProgress
            }
        }
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
