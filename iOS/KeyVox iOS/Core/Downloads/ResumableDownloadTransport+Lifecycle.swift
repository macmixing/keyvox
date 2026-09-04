import Foundation

extension ResumableDownloadTransport {
    func handleAppDidBecomeActive() async {
        if beginTransition(appIsActive: true) {
            await transition(to: .foreground)
        }
        await waitForLifecycleStability()
    }

    func handleAppWillResignActive() {
        guard beginTransition(appIsActive: false) else { return }
        Task { [weak self] in
            await self?.transition(to: .background)
        }
    }

    private func beginTransition(appIsActive: Bool) -> Bool {
        withLifecycleLock {
            self.appIsActive = appIsActive
            guard !isTransitioning else { return false }
            isTransitioning = true
            return true
        }
    }

    private func transition(to destination: ResumableDownloadSessionKind) async {
        defer {
            completeTransition(currentSession: destination)
        }

        let source: ResumableDownloadSessionKind = destination == .foreground ? .background : .foreground
        let sourceTasks = await downloadTasks(in: source)
        var resumeDataByArtifactID = takePendingResumeData()

        for task in sourceTasks {
            guard let descriptor = taskDescriptor(for: task) else {
                task.cancel()
                continue
            }
            if let resumeData = await cancelProducingResumeData(task) {
                resumeDataByArtifactID[descriptor.artifactID] = resumeData
            }
        }

        guard let delegate else {
            storePendingResumeData(resumeDataByArtifactID)
            return
        }
        let remainingResumeData = await delegate.resumableDownloadTransport(
            self,
            prepareDownloadsFor: destination,
            resumeDataByArtifactID: resumeDataByArtifactID
        )
        storePendingResumeData(remainingResumeData)
    }

    private func completeTransition(currentSession: ResumableDownloadSessionKind) {
        let currentSessionIsForeground = currentSession == .foreground
        var stabilityWaiters: [CheckedContinuation<Void, Never>] = []
        let nextSession = withLifecycleLock { () -> ResumableDownloadSessionKind? in
            guard appIsActive != currentSessionIsForeground else {
                isTransitioning = false
                stabilityWaiters = lifecycleStabilityWaiters
                lifecycleStabilityWaiters.removeAll()
                return nil
            }
            return appIsActive ? .foreground : .background
        }
        stabilityWaiters.forEach { $0.resume() }
        guard let nextSession else { return }

        Task { [weak self] in
            await self?.transition(to: nextSession)
        }
    }

    private func cancelProducingResumeData(_ task: URLSessionDownloadTask) async -> Data? {
        await withCheckedContinuation { continuation in
            task.cancel { resumeData in
                continuation.resume(returning: resumeData)
            }
        }
    }

    private func waitForLifecycleStability() async {
        await withCheckedContinuation { continuation in
            let shouldResumeImmediately = withLifecycleLock {
                guard isTransitioning else { return true }
                lifecycleStabilityWaiters.append(continuation)
                return false
            }
            if shouldResumeImmediately {
                continuation.resume()
            }
        }
    }
}
