import Foundation

extension LocalRewriteBackgroundDownloadCoordinator {
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
        do {
            let updatedJob = try withJobStoreLock { () -> LocalRewriteBackgroundDownloadJob? in
                guard var job = jobStore.load(),
                      job.id == descriptor.jobID,
                      job.artifactFilename == descriptor.artifactID else {
                    return nil
                }
                let destinationURL = try stagingArtifactURLProvider()
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                if fileManager.fileExists(atPath: destinationURL.path) {
                    try fileManager.removeItem(at: destinationURL)
                }
                try fileManager.moveItem(at: location, to: destinationURL)
                let fileSize = (
                    try fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber
                )?.int64Value ?? 0
                job.phase = .downloaded
                job.taskIdentifier = nil
                job.completedBytes = max(job.completedBytes, fileSize)
                job.expectedBytes = max(job.expectedBytes ?? job.expectedByteCount, fileSize)
                job.finalizationState = .pending
                job.lastErrorMessage = nil
                job.updatedAt = .now
                try jobStore.save(job)
                return job
            }
            guard let updatedJob else { return }
            stateDidChange?(updatedJob)
        } catch {
            markDownloadFailed(for: descriptor)
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
        markDownloadFailed(for: descriptor)
    }
}
