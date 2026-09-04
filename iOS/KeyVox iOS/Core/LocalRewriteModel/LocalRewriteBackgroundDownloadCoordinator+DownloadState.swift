import Foundation

extension LocalRewriteBackgroundDownloadCoordinator {
    func updateDownloadProgress(
        for descriptor: ResumableDownloadTaskDescriptor,
        taskIdentifier: Int,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let job = withJobStoreLock { () -> LocalRewriteBackgroundDownloadJob? in
            guard var job = jobStore.load(),
                  job.id == descriptor.jobID,
                  job.artifactFilename == descriptor.artifactID else {
                return nil
            }

            let previousProgress = job.downloadProgressFraction
            job.phase = .downloading
            job.taskIdentifier = taskIdentifier
            job.completedBytes = max(job.completedBytes, max(totalBytesWritten, 0))
            if totalBytesExpectedToWrite > 0 {
                job.expectedBytes = max(
                    job.expectedBytes ?? job.expectedByteCount,
                    totalBytesExpectedToWrite
                )
            }
            job.lastErrorMessage = nil
            job.updatedAt = .now

            guard job.downloadProgressFraction - previousProgress >= Self.minimumProgressPersistenceFraction else {
                return nil
            }
            try? jobStore.save(job)
            return job
        }
        guard let job else { return }
        stateDidChange?(job)
    }

    func markDownloadFailed(for descriptor: ResumableDownloadTaskDescriptor) {
        let job = withJobStoreLock { () -> LocalRewriteBackgroundDownloadJob? in
            guard var job = jobStore.load(),
                  job.id == descriptor.jobID,
                  job.artifactFilename == descriptor.artifactID else {
                return nil
            }
            job.phase = .failed
            job.taskIdentifier = nil
            job.finalizationState = .failed
            job.lastErrorMessage = Self.downloadFailureMessage
            job.updatedAt = .now
            try? jobStore.save(job)
            return job
        }
        guard let job else { return }
        stateDidChange?(job)
    }
}
