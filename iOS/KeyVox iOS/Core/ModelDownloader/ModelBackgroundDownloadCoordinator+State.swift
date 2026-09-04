import Foundation

extension ModelBackgroundDownloadCoordinator {
    func withJobStoreLock<T>(_ operation: () throws -> T) rethrows -> T {
        jobStoreLock.lock()
        defer { jobStoreLock.unlock() }
        return try operation()
    }

    func persist(_ job: ModelBackgroundDownloadJob) throws {
        try withJobStoreLock {
            try jobStore.save(job)
        }
        stateDidChange?(job)
    }

    func updateLoadedJob(
        matching jobID: UUID? = nil,
        _ mutate: (inout ModelBackgroundDownloadJob) -> Void
    ) {
        let job = withJobStoreLock { () -> ModelBackgroundDownloadJob? in
            guard var job = jobStore.load(), jobID == nil || job.id == jobID else {
                return nil
            }
            mutate(&job)
            job.touch()
            try? jobStore.save(job)
            return job
        }
        guard let job else { return }
        stateDidChange?(job)
    }

    func updateArtifact(
        for descriptor: ResumableDownloadTaskDescriptor,
        _ mutate: (inout ModelBackgroundDownloadJob, inout ModelBackgroundArtifactState) -> Void
    ) {
        let job = withJobStoreLock { () -> ModelBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == descriptor.jobID else { return nil }
            var artifactState = job.artifactState(for: descriptor.artifactID)
            mutate(&job, &artifactState)
            job.setArtifactState(artifactState, for: descriptor.artifactID)
            try? jobStore.save(job)
            return job
        }
        guard let job else { return }
        stateDidChange?(job)
    }

    func updateDownloadProgress(
        for descriptor: ResumableDownloadTaskDescriptor,
        taskIdentifier: Int,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let job = loadJob(), job.id == descriptor.jobID else { return }
        let artifact = DictationModelCatalog
            .descriptor(for: job.modelID)
            .artifacts
            .first(where: { $0.relativePath == descriptor.artifactID })

        updateArtifact(for: descriptor) { _, artifactState in
            artifactState.phase = .downloading
            artifactState.taskIdentifier = taskIdentifier
            artifactState.completedBytes = max(artifactState.completedBytes, max(totalBytesWritten, 0))
            let reportedExpectedBytes = totalBytesExpectedToWrite > 0
                ? totalBytesExpectedToWrite
                : artifact?.progressTotalBytes
            if let reportedExpectedBytes {
                artifactState.expectedBytes = max(
                    artifactState.expectedBytes ?? 0,
                    reportedExpectedBytes
                )
            }
            artifactState.errorMessage = nil
            artifactState.updatedAt = .now
        }
    }
}
