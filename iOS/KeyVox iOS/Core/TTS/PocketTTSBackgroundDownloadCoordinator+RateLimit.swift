import Foundation

extension PocketTTSBackgroundDownloadCoordinator {
    func markArtifactWaitingForRateLimitRetry(
        for descriptor: ResumableDownloadTaskDescriptor,
        response: HTTPURLResponse
    ) {
        let retryDate = rateLimitRetryDate(from: response)
        let retryDelay = max(Int(retryDate.timeIntervalSinceNow.rounded(.up)), 1)
        #if DEBUG
        NSLog(
            "[PocketTTSBackgroundDownloadCoordinator] HTTP 429 for %@. Retrying after %d seconds.",
            descriptor.artifactID,
            retryDelay
        )
        #endif
        updateArtifact(for: descriptor) { state, _ in
            state.phase = .pending
            state.taskIdentifier = nil
            state.completedBytes = 0
            state.retryNotBefore = retryDate
            state.errorMessage = nil
            state.updatedAt = .now
        }
    }

    func retryRateLimitedArtifactIfNeeded(for descriptor: ResumableDownloadTaskDescriptor) {
        let update = try? withJobStoreLock { () -> (PocketTTSBackgroundDownloadJob, URLSessionDownloadTask)? in
            guard var job = jobStore.load(),
                  job.id == descriptor.jobID,
                  job.finalizationState != .failed,
                  let artifact = job.artifacts.first(where: { $0.relativePath == descriptor.artifactID }) else {
                return nil
            }

            var state = job.artifactState(for: descriptor.artifactID)
            guard state.phase == .pending, state.retryNotBefore != nil else { return nil }

            let task = transport.session(for: .background).downloadTask(with: artifact.remoteURL)
            task.taskDescription = descriptor.encoded
            task.earliestBeginDate = state.retryNotBefore
            state.phase = .downloading
            state.taskIdentifier = task.taskIdentifier
            state.completedBytes = 0
            state.expectedBytes = artifact.expectedByteCount
            state.errorMessage = nil
            state.updatedAt = .now
            job.setArtifactState(state, for: descriptor.artifactID)
            job.lastErrorMessage = nil
            job.finalizationState = .awaitingDownloads
            try jobStore.save(job)
            return (job, task)
        }

        guard let update else { return }
        stateDidChange?(update.0)
        update.1.resume()
    }

    private func rateLimitRetryDate(from response: HTTPURLResponse) -> Date {
        if let retryAfter = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = TimeInterval(retryAfter) {
            return Date().addingTimeInterval(max(seconds, 1))
        }

        if let rateLimit = response.value(forHTTPHeaderField: "RateLimit"),
           let timeRange = rateLimit.range(of: "t="),
           let seconds = TimeInterval(
               String(rateLimit[timeRange.upperBound...].prefix { $0.isNumber })
           ) {
            return Date().addingTimeInterval(max(seconds, 1))
        }

        return Date().addingTimeInterval(60)
    }
}
