import Foundation

final class PocketTTSBackgroundDownloadCoordinator: ResumableDownloadTransportDelegate {
    static let sessionIdentifier = "com.cueit.keyvox.speak-download.background-session"
    static let minimumProgressPersistenceFraction = 0.01

    var stateDidChange: (@Sendable (PocketTTSBackgroundDownloadJob?) -> Void)?

    let fileManager: FileManager
    let jobStore: PocketTTSBackgroundDownloadJobStore
    let stagingRootProvider: (PocketTTSInstallTarget) throws -> URL
    let jobStoreLock = NSLock()
    lazy var transport = ResumableDownloadTransport(
        sessionIdentifier: Self.sessionIdentifier,
        sharedContainerIdentifier: SharedPaths.appGroupID,
        delegate: self
    )

    init(
        fileManager: FileManager = .default,
        jobStore: PocketTTSBackgroundDownloadJobStore,
        stagingRootProvider: @escaping (PocketTTSInstallTarget) throws -> URL
    ) {
        self.fileManager = fileManager
        self.jobStore = jobStore
        self.stagingRootProvider = stagingRootProvider
    }

    func loadJob() -> PocketTTSBackgroundDownloadJob? {
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

    func startOrResumeJob(_ requestedJob: PocketTTSBackgroundDownloadJob) async throws {
        let stagingRootURL = try stagingRootProvider(requestedJob.target)
        try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        let initialJob = try withJobStoreLock {
            let job = jobStore.load().flatMap { $0.id == requestedJob.id ? $0 : nil } ?? requestedJob
            try jobStore.save(job)
            return job
        }
        stateDidChange?(initialJob)

        let backgroundTasks = await transport.downloadTasks(in: .background)
        let foregroundTasks = await transport.downloadTasks(in: .foreground)
        let allTasks = backgroundTasks + foregroundTasks
        allTasks.filter { transport.taskDescriptor(for: $0)?.jobID != requestedJob.id }.forEach { $0.cancel() }

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
        let transferSession = transport.session(for: sessionKind)
        var resumeDataByRelativePath = useBackgroundSession ? [:] : transport.takePendingResumeData()

        let job = try withJobStoreLock { () -> PocketTTSBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == requestedJob.id else { return nil }
            try prepareDownloads(
                in: &job,
                stagingRootURL: stagingRootURL,
                existingTasks: existingTasks,
                session: transferSession,
                schedulesEntireJob: useBackgroundSession,
                resumeDataByRelativePath: &resumeDataByRelativePath
            )
            try jobStore.save(job)
            return job
        }

        if !useBackgroundSession {
            transport.storePendingResumeData(resumeDataByRelativePath)
        }
        guard let job else { return }
        stateDidChange?(job)
    }

    func synchronizeWithSystemTasks() async -> PocketTTSBackgroundDownloadJob? {
        guard let jobID = loadJob()?.id else { return nil }
        let backgroundTasks = await transport.downloadTasks(in: .background)
        let foregroundTasks = await transport.downloadTasks(in: .foreground)
        let tasks = backgroundTasks + foregroundTasks
        let tasksByRelativePath = transport.deduplicatedTasksByArtifactID(from: tasks, jobID: jobID)
        let job = withJobStoreLock { () -> PocketTTSBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == jobID else { return nil }

            for artifact in job.artifacts {
                var state = job.artifactState(for: artifact.relativePath)
                if state.phase == .downloaded { continue }
                if let task = tasksByRelativePath[artifact.relativePath] {
                    state.phase = .downloading
                    state.taskIdentifier = task.taskIdentifier
                    state.completedBytes = max(
                        state.completedBytes,
                        max(task.countOfBytesReceived, 0)
                    )
                    state.expectedBytes = task.countOfBytesExpectedToReceive > 0
                        ? task.countOfBytesExpectedToReceive
                        : artifact.expectedByteCount
                    state.errorMessage = nil
                    state.updatedAt = .now
                } else if state.phase == .downloading {
                    state.phase = .pending
                    state.taskIdentifier = nil
                    state.updatedAt = .now
                }
                job.setArtifactState(state, for: artifact.relativePath)
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

    func prepareDownloads(
        in job: inout PocketTTSBackgroundDownloadJob,
        stagingRootURL: URL,
        existingTasks: [String: URLSessionDownloadTask],
        session: URLSession,
        schedulesEntireJob: Bool,
        resumeDataByRelativePath: inout [String: Data]
    ) throws {
        for artifact in job.artifacts {
            var state = job.artifactState(for: artifact.relativePath)
            if state.phase == .downloaded {
                resumeDataByRelativePath.removeValue(forKey: artifact.relativePath)
                continue
            }

            if artifact.expectedByteCount == 0 {
                let destinationURL = try stagedArtifactURL(
                    stagingRootURL: stagingRootURL,
                    relativePath: artifact.relativePath
                )
                try fileManager.createDirectory(
                    at: destinationURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                try Data().write(to: destinationURL, options: .atomic)
                state.phase = .downloaded
                state.taskIdentifier = nil
                state.completedBytes = 0
                state.expectedBytes = 0
                state.retryNotBefore = nil
                state.errorMessage = nil
                state.updatedAt = .now
                job.setArtifactState(state, for: artifact.relativePath)
                continue
            }

            let task: URLSessionDownloadTask
            if let existingTask = existingTasks[artifact.relativePath] {
                resumeDataByRelativePath.removeValue(forKey: artifact.relativePath)
                task = existingTask
                state.completedBytes = max(
                    state.completedBytes,
                    max(existingTask.countOfBytesReceived, 0)
                )
                state.expectedBytes = existingTask.countOfBytesExpectedToReceive > 0
                    ? existingTask.countOfBytesExpectedToReceive
                    : artifact.expectedByteCount
            } else if let resumeData = resumeDataByRelativePath.removeValue(forKey: artifact.relativePath) {
                task = session.downloadTask(withResumeData: resumeData)
                task.taskDescription = ResumableDownloadTaskDescriptor(jobID: job.id, artifactID: artifact.relativePath).encoded
                state.expectedBytes = artifact.expectedByteCount
            } else {
                task = session.downloadTask(with: artifact.remoteURL)
                task.taskDescription = ResumableDownloadTaskDescriptor(jobID: job.id, artifactID: artifact.relativePath).encoded
                task.earliestBeginDate = state.retryNotBefore
                state.expectedBytes = artifact.expectedByteCount
            }

            state.phase = .downloading
            state.taskIdentifier = task.taskIdentifier
            state.errorMessage = nil
            state.updatedAt = .now
            job.setArtifactState(state, for: artifact.relativePath)
            job.lastErrorMessage = nil
            job.finalizationState = .awaitingDownloads
            task.resume()
            if !schedulesEntireJob {
                return
            }
        }

        job.lastErrorMessage = nil
        job.finalizationState = job.isReadyForFinalization ? .pending : .awaitingDownloads
    }

    func stagedArtifactURL(stagingRootURL: URL, relativePath: String) throws -> URL {
        let standardizedRootURL = stagingRootURL.standardizedFileURL
        let destinationURL = standardizedRootURL.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = standardizedRootURL.path.hasSuffix("/")
            ? standardizedRootURL.path
            : standardizedRootURL.path + "/"
        guard destinationURL.path.hasPrefix(rootPath) else {
            throw CocoaError(.fileWriteInvalidFileName)
        }
        return destinationURL
    }

    func withJobStoreLock<T>(_ operation: () throws -> T) rethrows -> T {
        jobStoreLock.lock()
        defer { jobStoreLock.unlock() }
        return try operation()
    }

    func updateLoadedJob(_ mutate: (inout PocketTTSBackgroundDownloadJob) -> Void) {
        let job = withJobStoreLock { () -> PocketTTSBackgroundDownloadJob? in
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
