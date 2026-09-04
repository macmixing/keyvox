import Foundation

extension LocalRewriteBackgroundDownloadCoordinator {
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
        let job = withJobStoreLock { () -> LocalRewriteBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == existingJob.id else { return nil }
            prepareDownload(
                in: &job,
                existingTask: existingTasks[job.artifactFilename],
                session: transport.session(for: sessionKind),
                resumeDataByArtifactID: &remainingResumeData
            )
            try? jobStore.save(job)
            return job
        }
        guard let job else { return remainingResumeData }
        stateDidChange?(job)
        return remainingResumeData
    }
}
