import Foundation

extension ModelBackgroundDownloadCoordinator {
    func resumableDownloadTransport(
        _ transport: ResumableDownloadTransport,
        prepareDownloadsFor sessionKind: ResumableDownloadSessionKind,
        resumeDataByArtifactID: [String: Data]
    ) async -> [String: Data] {
        var remainingResumeData = resumeDataByArtifactID
        guard let existingJob = loadJob() else { return [:] }

        let sessionTasks = await transport.downloadTasks(in: sessionKind)
        let existingTasks = transport.deduplicatedTasksByArtifactID(
            from: sessionTasks,
            jobID: existingJob.id
        )

        do {
            try ensureStagingDirectoryExists(for: existingJob.modelID)
            let job = try withJobStoreLock { () -> ModelBackgroundDownloadJob? in
                guard var job = jobStore.load(), job.id == existingJob.id else { return nil }
                prepareDownloads(
                    in: &job,
                    existingTasks: existingTasks,
                    session: transport.session(for: sessionKind),
                    resumeDataByArtifactID: &remainingResumeData
                )
                try jobStore.save(job)
                return job
            }
            guard let job else { return remainingResumeData }
            stateDidChange?(job)
        } catch {
            markJobFailed(jobID: existingJob.id, error: error)
        }

        return remainingResumeData
    }

    func prepareDownloads(
        in job: inout ModelBackgroundDownloadJob,
        existingTasks: [String: URLSessionDownloadTask],
        session: URLSession,
        resumeDataByArtifactID: inout [String: Data]
    ) {
        let descriptor = DictationModelCatalog.descriptor(for: job.modelID)

        for artifact in descriptor.artifacts {
            var artifactState = job.artifactState(for: artifact.relativePath)
            if artifactState.phase == .downloaded {
                resumeDataByArtifactID.removeValue(forKey: artifact.relativePath)
                artifactState.taskIdentifier = nil
                job.setArtifactState(artifactState, for: artifact.relativePath)
                continue
            }

            let task: URLSessionDownloadTask
            if let existingTask = existingTasks[artifact.relativePath] {
                resumeDataByArtifactID.removeValue(forKey: artifact.relativePath)
                task = existingTask
                artifactState.completedBytes = max(
                    artifactState.completedBytes,
                    max(existingTask.countOfBytesReceived, 0)
                )
                if existingTask.countOfBytesExpectedToReceive > 0 {
                    artifactState.expectedBytes = max(
                        artifactState.expectedBytes ?? artifact.progressTotalBytes,
                        existingTask.countOfBytesExpectedToReceive
                    )
                }
            } else if let resumeData = resumeDataByArtifactID.removeValue(forKey: artifact.relativePath) {
                task = session.downloadTask(withResumeData: resumeData)
            } else {
                task = session.downloadTask(with: artifact.remoteURL)
            }

            task.taskDescription = ResumableDownloadTaskDescriptor(
                jobID: job.id,
                artifactID: artifact.relativePath
            ).encoded
            artifactState.phase = .downloading
            artifactState.taskIdentifier = task.taskIdentifier
            artifactState.expectedBytes = max(
                artifactState.expectedBytes ?? artifact.progressTotalBytes,
                artifact.progressTotalBytes
            )
            artifactState.errorMessage = nil
            artifactState.updatedAt = .now
            job.setArtifactState(artifactState, for: artifact.relativePath)
            task.resume()
        }

        job.lastErrorMessage = nil
        job.finalizationState = job.isReadyForFinalization ? .pending : .awaitingDownloads
    }
}
