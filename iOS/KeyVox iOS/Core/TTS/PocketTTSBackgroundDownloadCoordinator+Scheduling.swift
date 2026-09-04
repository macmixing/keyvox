import Foundation

extension PocketTTSBackgroundDownloadCoordinator {
    func resumeForegroundDownloadIfNeeded(for jobID: UUID) {
        guard transport.isReadyForForegroundScheduling() else { return }

        var resumeDataByRelativePath = transport.takePendingResumeData()
        defer { transport.storePendingResumeData(resumeDataByRelativePath) }
        do {
            guard let existingJob = loadJob(),
                  existingJob.id == jobID,
                  existingJob.finalizationState != .failed else {
                return
            }
            let stagingRootURL = try stagingRootProvider(existingJob.target)
            try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
            let job = try withJobStoreLock { () -> PocketTTSBackgroundDownloadJob? in
                guard var job = jobStore.load(), job.id == jobID else { return nil }
                try prepareDownloads(
                    in: &job,
                    stagingRootURL: stagingRootURL,
                    existingTasks: [:],
                    session: transport.session(for: .foreground),
                    schedulesEntireJob: false,
                    resumeDataByRelativePath: &resumeDataByRelativePath
                )
                try jobStore.save(job)
                return job
            }
            guard let job else { return }
            stateDidChange?(job)
        } catch {
            markJobFailed(jobID: jobID, error: error)
        }
    }
}
