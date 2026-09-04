import Foundation

extension ModelBackgroundDownloadCoordinator {
    func resumableDownloadTransport(
        _ transport: ResumableDownloadTransport,
        didWriteDataFor descriptor: ResumableDownloadTaskDescriptor,
        taskIdentifier: Int,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        updateDownloadProgress(
            for: descriptor,
            taskIdentifier: taskIdentifier,
            totalBytesWritten: totalBytesWritten,
            totalBytesExpectedToWrite: totalBytesExpectedToWrite
        )
    }

    func resumableDownloadTransport(
        _ transport: ResumableDownloadTransport,
        didFinishDownloading descriptor: ResumableDownloadTaskDescriptor,
        to location: URL,
        response: URLResponse?
    ) {
        guard let job = loadJob(), job.id == descriptor.jobID,
              let stagedURL = modelLocator.stagedArtifactURL(
                for: job.modelID,
                relativePath: descriptor.artifactID
              ) else {
            return
        }

        do {
            if let httpResponse = response as? HTTPURLResponse,
               !(200 ... 299).contains(httpResponse.statusCode) {
                throw URLError(.badServerResponse)
            }

            let parentDirectoryURL = stagedURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectoryURL.path) {
                try fileManager.createDirectory(at: parentDirectoryURL, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: stagedURL.path) {
                try fileManager.removeItem(at: stagedURL)
            }
            try fileManager.moveItem(at: location, to: stagedURL)

            let fileSize = (
                try? fileManager.attributesOfItem(atPath: stagedURL.path)[.size] as? NSNumber
            )?.int64Value ?? 0
            updateArtifact(for: descriptor) { job, artifactState in
                artifactState.phase = .downloaded
                artifactState.taskIdentifier = nil
                artifactState.completedBytes = max(artifactState.completedBytes, fileSize)
                artifactState.expectedBytes = max(artifactState.expectedBytes ?? 0, fileSize)
                artifactState.errorMessage = nil
                artifactState.updatedAt = .now
                if job.isReadyForFinalization {
                    job.finalizationState = .pending
                    job.lastErrorMessage = nil
                }
            }
        } catch {
            markArtifactFailed(for: descriptor, error: error)
        }
    }

    func resumableDownloadTransport(
        _ transport: ResumableDownloadTransport,
        didComplete descriptor: ResumableDownloadTaskDescriptor,
        in sessionKind: ResumableDownloadSessionKind,
        error: Error?
    ) {
        guard let error else { return }
        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else {
            return
        }
        markArtifactFailed(for: descriptor, error: error)
    }

    func markArtifactFailed(for descriptor: ResumableDownloadTaskDescriptor, error: Error) {
        updateArtifact(for: descriptor) { job, artifactState in
            artifactState.phase = .failed
            artifactState.taskIdentifier = nil
            artifactState.errorMessage = error.localizedDescription
            artifactState.updatedAt = .now
            job.lastErrorMessage = error.localizedDescription
            job.finalizationState = .failed
        }
    }

    func markJobFailed(jobID: UUID, error: Error) {
        updateLoadedJob(matching: jobID) { job in
            job.lastErrorMessage = error.localizedDescription
            job.finalizationState = .failed
        }
    }
}
