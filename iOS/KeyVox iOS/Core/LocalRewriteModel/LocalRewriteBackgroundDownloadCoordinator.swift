import Foundation

final class LocalRewriteBackgroundDownloadCoordinator: ResumableDownloadTransportDelegate {
    static let sessionIdentifier = "com.cueit.keyvox.vibes-download.background-session"
    static let minimumProgressPersistenceFraction = 0.01
    static let downloadFailureMessage = "Vibes model download failed. Check your network/storage and retry."

    var stateDidChange: (@Sendable (LocalRewriteBackgroundDownloadJob?) -> Void)?

    let fileManager: FileManager
    let jobStore: LocalRewriteBackgroundDownloadJobStore
    let stagingArtifactURLProvider: () throws -> URL
    let jobStoreLock = NSLock()
    let transport: ResumableDownloadTransport

    init(
        fileManager: FileManager = .default,
        jobStore: LocalRewriteBackgroundDownloadJobStore,
        stagingArtifactURLProvider: @escaping () throws -> URL
    ) {
        self.fileManager = fileManager
        self.jobStore = jobStore
        self.stagingArtifactURLProvider = stagingArtifactURLProvider
        self.transport = ResumableDownloadTransport(
            sessionIdentifier: Self.sessionIdentifier,
            sharedContainerIdentifier: SharedPaths.appGroupID,
            delegate: nil
        )
        self.transport.delegate = self
    }

    func loadJob() -> LocalRewriteBackgroundDownloadJob? {
        withJobStoreLock {
            jobStore.load()
        }
    }

    func registerBackgroundSessionCompletionHandler(_ completionHandler: @escaping () -> Void) {
        transport.registerBackgroundSessionCompletionHandler(completionHandler)
    }

    func handleAppDidBecomeActive() async {
        await transport.handleAppDidBecomeActive()
    }

    func handleAppWillResignActive() {
        transport.handleAppWillResignActive()
    }

    func startOrResumeJob(_ requestedJob: LocalRewriteBackgroundDownloadJob) async throws {
        let stagingArtifactURL = try stagingArtifactURLProvider()
        try fileManager.createDirectory(
            at: stagingArtifactURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let initialJob = try withJobStoreLock {
            let job = jobStore.load().flatMap { $0.id == requestedJob.id ? $0 : nil } ?? requestedJob
            try jobStore.save(job)
            return job
        }
        stateDidChange?(initialJob)

        let backgroundTasks = await transport.downloadTasks(in: .background)
        let foregroundTasks = await transport.downloadTasks(in: .foreground)
        let allTasks = backgroundTasks + foregroundTasks
        allTasks
            .filter { transport.taskDescriptor(for: $0)?.jobID != requestedJob.id }
            .forEach { $0.cancel() }

        let useBackgroundSession = transport.shouldUseBackgroundSession(
            jobID: requestedJob.id,
            existingBackgroundTasks: backgroundTasks
        )
        if useBackgroundSession {
            foregroundTasks
                .filter { transport.taskDescriptor(for: $0)?.jobID == requestedJob.id }
                .forEach { $0.cancel() }
        }

        let existingTasks = transport.deduplicatedTasksByArtifactID(
            from: useBackgroundSession ? backgroundTasks : foregroundTasks,
            jobID: requestedJob.id
        )
        let sessionKind: ResumableDownloadSessionKind = useBackgroundSession ? .background : .foreground
        var resumeDataByArtifactID = useBackgroundSession ? [:] : transport.takePendingResumeData()
        let job = try withJobStoreLock { () -> LocalRewriteBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == requestedJob.id else { return nil }
            prepareDownload(
                in: &job,
                existingTask: existingTasks[job.artifactFilename],
                session: transport.session(for: sessionKind),
                resumeDataByArtifactID: &resumeDataByArtifactID
            )
            try jobStore.save(job)
            return job
        }

        if !useBackgroundSession {
            transport.storePendingResumeData(resumeDataByArtifactID)
        }
        guard let job else { return }
        stateDidChange?(job)
    }

    func synchronizeWithSystemTasks() async -> LocalRewriteBackgroundDownloadJob? {
        guard let jobID = loadJob()?.id else { return nil }
        let backgroundTasks = await transport.downloadTasks(in: .background)
        let foregroundTasks = await transport.downloadTasks(in: .foreground)
        let tasks = backgroundTasks + foregroundTasks
        let tasksByArtifactID = transport.deduplicatedTasksByArtifactID(from: tasks, jobID: jobID)
        let job = withJobStoreLock { () -> LocalRewriteBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == jobID else { return nil }

            if job.phase != .downloaded {
                if let task = tasksByArtifactID[job.artifactFilename] {
                    job.phase = .downloading
                    job.taskIdentifier = task.taskIdentifier
                    job.completedBytes = max(job.completedBytes, max(task.countOfBytesReceived, 0))
                    if task.countOfBytesExpectedToReceive > 0 {
                        job.expectedBytes = max(
                            job.expectedBytes ?? job.expectedByteCount,
                            task.countOfBytesExpectedToReceive
                        )
                    }
                    job.lastErrorMessage = nil
                    job.updatedAt = .now
                } else if job.phase == .downloading {
                    job.phase = .pending
                    job.taskIdentifier = nil
                    job.updatedAt = .now
                }
            }

            if job.isReadyForFinalization, job.finalizationState != .inProgress {
                job.finalizationState = .pending
            }
            try? jobStore.save(job)
            return job
        }
        stateDidChange?(job)
        return job
    }

    func markFinalizationInProgress() {
        updateLoadedJob {
            $0.finalizationState = .inProgress
            $0.lastErrorMessage = nil
        }
    }

    func markFinalizationFailed(message: String) {
        updateLoadedJob {
            $0.finalizationState = .failed
            $0.lastErrorMessage = message
        }
    }

    func clearJob() async {
        await transport.cancelAllTasks()
        withJobStoreLock {
            try? jobStore.clear()
        }
        stateDidChange?(nil)
    }

    func cancelAndClearJob() {
        transport.cancelAllTasksWithoutWaiting()
        withJobStoreLock {
            try? jobStore.clear()
        }
        stateDidChange?(nil)
    }

    func prepareDownload(
        in job: inout LocalRewriteBackgroundDownloadJob,
        existingTask: URLSessionDownloadTask?,
        session: URLSession,
        resumeDataByArtifactID: inout [String: Data]
    ) {
        guard job.phase != .downloaded else {
            resumeDataByArtifactID.removeValue(forKey: job.artifactFilename)
            return
        }

        let task: URLSessionDownloadTask
        if let existingTask {
            resumeDataByArtifactID.removeValue(forKey: job.artifactFilename)
            task = existingTask
            job.completedBytes = max(job.completedBytes, max(existingTask.countOfBytesReceived, 0))
            if existingTask.countOfBytesExpectedToReceive > 0 {
                job.expectedBytes = max(
                    job.expectedBytes ?? job.expectedByteCount,
                    existingTask.countOfBytesExpectedToReceive
                )
            }
        } else if let resumeData = resumeDataByArtifactID.removeValue(forKey: job.artifactFilename) {
            task = session.downloadTask(withResumeData: resumeData)
        } else {
            task = session.downloadTask(with: job.remoteURL)
        }

        task.taskDescription = ResumableDownloadTaskDescriptor(
            jobID: job.id,
            artifactID: job.artifactFilename
        ).encoded
        job.phase = .downloading
        job.taskIdentifier = task.taskIdentifier
        job.finalizationState = .awaitingDownload
        job.lastErrorMessage = nil
        job.updatedAt = .now
        task.resume()
    }

    func withJobStoreLock<T>(_ operation: () throws -> T) rethrows -> T {
        jobStoreLock.lock()
        defer { jobStoreLock.unlock() }
        return try operation()
    }

    func updateLoadedJob(_ mutate: (inout LocalRewriteBackgroundDownloadJob) -> Void) {
        let job = withJobStoreLock { () -> LocalRewriteBackgroundDownloadJob? in
            guard var job = jobStore.load() else { return nil }
            mutate(&job)
            job.updatedAt = .now
            try? jobStore.save(job)
            return job
        }
        guard let job else { return }
        stateDidChange?(job)
    }
}
