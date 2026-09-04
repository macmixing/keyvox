import Foundation

extension PocketTTSBackgroundDownloadCoordinator {
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
            let stagingRootURL = try stagingRootProvider(existingJob.target)
            try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
            let job = try withJobStoreLock { () -> PocketTTSBackgroundDownloadJob? in
                guard var job = jobStore.load(), job.id == existingJob.id else { return nil }
                try prepareDownloads(
                    in: &job,
                    stagingRootURL: stagingRootURL,
                    existingTasks: existingTasks,
                    session: transport.session(for: sessionKind),
                    schedulesEntireJob: sessionKind == .background,
                    resumeDataByRelativePath: &remainingResumeData
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
}
