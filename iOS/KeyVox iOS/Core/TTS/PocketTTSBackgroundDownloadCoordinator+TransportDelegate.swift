import Foundation

extension PocketTTSBackgroundDownloadCoordinator {
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
        guard let job = loadJob(), job.id == descriptor.jobID else { return }

        do {
            guard let response = response as? HTTPURLResponse else {
                throw URLError(.badServerResponse)
            }
            guard 200 ..< 300 ~= response.statusCode else {
                if response.statusCode == 429 {
                    markArtifactWaitingForRateLimitRetry(for: descriptor, response: response)
                    return
                }
                throw NSError(
                    domain: "PocketTTSBackgroundDownloadCoordinator",
                    code: response.statusCode,
                    userInfo: [
                        NSLocalizedDescriptionKey: "Speak download failed with HTTP \(response.statusCode) for \(descriptor.artifactID).",
                    ]
                )
            }
            let stagingRootURL = try stagingRootProvider(job.target)
            let destinationURL = try stagedArtifactURL(
                stagingRootURL: stagingRootURL,
                relativePath: descriptor.artifactID
            )
            try fileManager.createDirectory(
                at: destinationURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: location, to: destinationURL)
            let fileSize = (try fileManager.attributesOfItem(atPath: destinationURL.path)[.size] as? NSNumber)?.int64Value ?? 0
            updateArtifact(for: descriptor) { state, _ in
                state.phase = .downloaded
                state.taskIdentifier = nil
                state.completedBytes = fileSize
                state.expectedBytes = max(state.expectedBytes ?? 0, fileSize)
                state.retryNotBefore = nil
                state.errorMessage = nil
                state.updatedAt = .now
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
        guard let error else {
            if sessionKind == .foreground {
                resumeForegroundDownloadIfNeeded(for: descriptor.jobID)
            } else {
                retryRateLimitedArtifactIfNeeded(for: descriptor)
            }
            return
        }
        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
        markArtifactFailed(for: descriptor, error: error)
    }

}
