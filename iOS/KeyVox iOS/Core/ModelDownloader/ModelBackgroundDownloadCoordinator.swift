import Foundation

struct ModelBackgroundDownloadTaskSnapshot: Sendable {
    let taskIdentifier: Int
    let completedBytes: Int64
    let expectedBytes: Int64
}

final class ModelBackgroundDownloadCoordinator: ResumableDownloadTransportDelegate {
    typealias StateChangeHandler = @Sendable (ModelBackgroundDownloadJob?) -> Void
    typealias TaskSnapshotProvider = @MainActor (UUID) async -> [String: ModelBackgroundDownloadTaskSnapshot]

    static let sessionIdentifier = "com.cueit.keyvox.model-download.background-session"

    var stateDidChange: StateChangeHandler?

    let fileManager: FileManager
    let jobStore: ModelBackgroundDownloadJobStore
    let modelLocator: InstalledDictationModelLocator
    let jobStoreLock = NSLock()
    let transport: ResumableDownloadTransport
    private let taskSnapshotProvider: TaskSnapshotProvider?

    init(
        fileManager: FileManager = .default,
        jobStore: ModelBackgroundDownloadJobStore,
        modelLocator: InstalledDictationModelLocator,
        taskSnapshotProvider: TaskSnapshotProvider? = nil
    ) {
        self.fileManager = fileManager
        self.jobStore = jobStore
        self.modelLocator = modelLocator
        self.taskSnapshotProvider = taskSnapshotProvider
        self.transport = ResumableDownloadTransport(
            sessionIdentifier: Self.sessionIdentifier,
            sharedContainerIdentifier: SharedPaths.appGroupID,
            delegate: nil
        )
        self.transport.delegate = self
    }

    func loadJob() -> ModelBackgroundDownloadJob? {
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

    func startOrResumeJob(for modelID: DictationModelID) async throws -> ModelBackgroundDownloadJob {
        try ensureStagingDirectoryExists(for: modelID)

        let initialJob = synchronizedJob(for: modelID)
        try persist(initialJob)

        let backgroundTasks = await transport.downloadTasks(in: .background)
        let foregroundTasks = await transport.downloadTasks(in: .foreground)
        let allTasks = backgroundTasks + foregroundTasks
        allTasks
            .filter { transport.taskDescriptor(for: $0)?.jobID != initialJob.id }
            .forEach { $0.cancel() }

        let useBackgroundSession = transport.shouldUseBackgroundSession(
            jobID: initialJob.id,
            existingBackgroundTasks: backgroundTasks
        )
        if useBackgroundSession {
            foregroundTasks
                .filter { transport.taskDescriptor(for: $0)?.jobID == initialJob.id }
                .forEach { $0.cancel() }
        }

        let sessionTasks = useBackgroundSession ? backgroundTasks : foregroundTasks
        let existingTasks = transport.deduplicatedTasksByArtifactID(
            from: sessionTasks,
            jobID: initialJob.id
        )
        let sessionKind: ResumableDownloadSessionKind = useBackgroundSession ? .background : .foreground
        var resumeDataByArtifactID = useBackgroundSession ? [:] : transport.takePendingResumeData()
        let job = try withJobStoreLock { () -> ModelBackgroundDownloadJob in
            var job = jobStore.load().flatMap { $0.id == initialJob.id ? $0 : nil } ?? initialJob
            prepareDownloads(
                in: &job,
                existingTasks: existingTasks,
                session: transport.session(for: sessionKind),
                resumeDataByArtifactID: &resumeDataByArtifactID
            )
            try jobStore.save(job)
            return job
        }

        if !useBackgroundSession {
            transport.storePendingResumeData(resumeDataByArtifactID)
        }
        stateDidChange?(job)
        return job
    }

    func synchronizeWithSystemTasks() async -> ModelBackgroundDownloadJob? {
        guard let existingJob = loadJob() else { return nil }

        let taskSnapshotsByRelativePath = await taskSnapshots(for: existingJob.id)
        let job = withJobStoreLock { () -> ModelBackgroundDownloadJob? in
            guard var job = jobStore.load(), job.id == existingJob.id else { return nil }
            let descriptor = DictationModelCatalog.descriptor(for: job.modelID)

            for artifact in descriptor.artifacts {
                var artifactState = job.artifactState(for: artifact.relativePath)
                if artifactState.phase == .downloaded {
                    artifactState.taskIdentifier = nil
                    job.setArtifactState(artifactState, for: artifact.relativePath)
                    continue
                }

                if let taskSnapshot = taskSnapshotsByRelativePath[artifact.relativePath] {
                    artifactState.phase = .downloading
                    artifactState.taskIdentifier = taskSnapshot.taskIdentifier
                    artifactState.completedBytes = max(
                        artifactState.completedBytes,
                        max(taskSnapshot.completedBytes, 0)
                    )
                    if taskSnapshot.expectedBytes > 0 {
                        artifactState.expectedBytes = max(
                            artifactState.expectedBytes ?? artifact.progressTotalBytes,
                            taskSnapshot.expectedBytes
                        )
                    }
                    artifactState.errorMessage = nil
                    artifactState.updatedAt = .now
                } else if artifactState.phase == .downloading {
                    artifactState.phase = .pending
                    artifactState.taskIdentifier = nil
                    artifactState.errorMessage = nil
                    artifactState.updatedAt = .now
                }

                job.setArtifactState(artifactState, for: artifact.relativePath)
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

    private func taskSnapshots(
        for jobID: UUID
    ) async -> [String: ModelBackgroundDownloadTaskSnapshot] {
        if let taskSnapshotProvider {
            return await taskSnapshotProvider(jobID)
        }

        let backgroundTasks = await transport.downloadTasks(in: .background)
        let foregroundTasks = await transport.downloadTasks(in: .foreground)
        let tasks = backgroundTasks + foregroundTasks
        let tasksByRelativePath = transport.deduplicatedTasksByArtifactID(
            from: tasks,
            jobID: jobID
        )

        return tasksByRelativePath.mapValues { task in
            ModelBackgroundDownloadTaskSnapshot(
                taskIdentifier: task.taskIdentifier,
                completedBytes: task.countOfBytesReceived,
                expectedBytes: task.countOfBytesExpectedToReceive
            )
        }
    }

    func markFinalizationInProgress() {
        updateLoadedJob {
            $0.finalizationState = .inProgress
            $0.lastErrorMessage = nil
        }
    }

    func markFinalizationPending() {
        updateLoadedJob {
            $0.finalizationState = .pending
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
        if let job = loadJob() {
            clearStagingArtifacts(for: job.modelID)
        }
        withJobStoreLock {
            try? jobStore.clear()
        }
        notifyStateChange(with: nil)
    }

    func cancelJob(for modelID: DictationModelID) async {
        guard loadJob()?.modelID == modelID else { return }
        await transport.cancelAllTasks()
    }

    private func synchronizedJob(for modelID: DictationModelID) -> ModelBackgroundDownloadJob {
        if let existingJob = loadJob(), existingJob.modelID == modelID {
            return existingJob
        }

        return ModelBackgroundDownloadJob(modelID: modelID)
    }

    func ensureStagingDirectoryExists(for modelID: DictationModelID) throws {
        guard let modelsDirectoryURL = modelLocator.modelsDirectoryURL else {
            throw CocoaError(.fileNoSuchFile)
        }

        if !fileManager.fileExists(atPath: modelsDirectoryURL.path) {
            try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
        }

        guard let stagingDirectoryURL = modelLocator.stagedRootURL(for: modelID) else {
            throw CocoaError(.fileNoSuchFile)
        }

        if !fileManager.fileExists(atPath: stagingDirectoryURL.path) {
            try fileManager.createDirectory(at: stagingDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func clearStagingArtifacts(for modelID: DictationModelID) {
        guard let stagingRootURL = modelLocator.stagedRootURL(for: modelID),
              fileManager.fileExists(atPath: stagingRootURL.path) else {
            return
        }

        try? fileManager.removeItem(at: stagingRootURL)
    }

    private func notifyStateChange(with job: ModelBackgroundDownloadJob?) {
        stateDidChange?(job)
    }
}
