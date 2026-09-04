import Foundation

extension PocketTTSBackgroundDownloadCoordinator {
    func updateArtifact(
        for descriptor: ResumableDownloadTaskDescriptor,
        mutate: (inout PocketTTSBackgroundArtifactState, PocketTTSBackgroundArtifact) -> Void
    ) {
        let job = withJobStoreLock { () -> PocketTTSBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == descriptor.jobID,
                  let artifact = job.artifacts.first(where: { $0.relativePath == descriptor.artifactID }) else {
                return nil
            }
            var state = job.artifactState(for: descriptor.artifactID)
            mutate(&state, artifact)
            job.setArtifactState(state, for: descriptor.artifactID)
            if job.isReadyForFinalization {
                job.finalizationState = .pending
                job.lastErrorMessage = nil
            }
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
        let job = withJobStoreLock { () -> PocketTTSBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == descriptor.jobID,
                  let artifact = job.artifacts.first(where: { $0.relativePath == descriptor.artifactID }) else {
                return nil
            }

            let previousProgress = job.downloadProgressFraction
            var state = job.artifactState(for: descriptor.artifactID)
            state.phase = .downloading
            state.taskIdentifier = taskIdentifier
            state.completedBytes = max(totalBytesWritten, 0)
            state.expectedBytes = totalBytesExpectedToWrite > 0
                ? totalBytesExpectedToWrite
                : artifact.expectedByteCount
            state.retryNotBefore = nil
            state.errorMessage = nil
            state.updatedAt = .now
            job.setArtifactState(state, for: descriptor.artifactID)

            guard job.downloadProgressFraction - previousProgress >= Self.minimumProgressPersistenceFraction else {
                return nil
            }

            try? jobStore.save(job)
            return job
        }
        guard let job else { return }
        stateDidChange?(job)
    }

    func markArtifactFailed(for descriptor: ResumableDownloadTaskDescriptor, error: Error) {
        #if DEBUG
        NSLog(
            "[PocketTTSBackgroundDownloadCoordinator] Download failed for %@: %@",
            descriptor.artifactID,
            error.localizedDescription
        )
        #endif
        updateArtifact(for: descriptor) { state, _ in
            state.phase = .failed
            state.taskIdentifier = nil
            state.retryNotBefore = nil
            state.errorMessage = error.localizedDescription
            state.updatedAt = .now
        }
        markJobFailed(jobID: descriptor.jobID, error: error)
    }

    func markJobFailed(jobID: UUID, error: Error) {
        let job = withJobStoreLock { () -> PocketTTSBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == jobID else { return nil }
            job.finalizationState = .failed
            job.lastErrorMessage = error.localizedDescription
            job.updatedAt = .now
            try? jobStore.save(job)
            return job
        }
        guard let job else { return }
        stateDidChange?(job)
    }
}
