import Foundation

final class ModelBackgroundDownloadCoordinator: NSObject {
    typealias StateChangeHandler = @Sendable (ModelBackgroundDownloadJob?) -> Void

    static let sessionIdentifier = "com.cueit.keyvox.model-download.background-session"

    var stateDidChange: StateChangeHandler?

    private let fileManager: FileManager
    private let jobStore: ModelBackgroundDownloadJobStore
    private let modelLocator: InstalledDictationModelLocator
    private let completionHandlerLock = NSLock()
    private var backgroundSessionCompletionHandler: (() -> Void)?
    private lazy var session: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.sharedContainerIdentifier = SharedPaths.appGroupID
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        configuration.isDiscretionary = false
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    init(
        fileManager: FileManager = .default,
        jobStore: ModelBackgroundDownloadJobStore,
        modelLocator: InstalledDictationModelLocator
    ) {
        self.fileManager = fileManager
        self.jobStore = jobStore
        self.modelLocator = modelLocator
    }

    func loadJob() -> ModelBackgroundDownloadJob? {
        jobStore.load()
    }

    func registerBackgroundSessionCompletionHandler(_ completionHandler: @escaping () -> Void) {
        completionHandlerLock.lock()
        backgroundSessionCompletionHandler = completionHandler
        completionHandlerLock.unlock()
    }

    func startOrResumeJob(for modelID: DictationModelID) async throws -> ModelBackgroundDownloadJob {
        try ensureStagingDirectoryExists(for: modelID)

        var job = synchronizedJob(for: modelID)
        let descriptor = DictationModelCatalog.descriptor(for: modelID)
        let tasks = await allDownloadTasks()
        tasks
            .filter {
                guard let description = $0.taskDescription,
                      let taskDescriptor = ModelBackgroundTaskDescriptor(taskDescription: description) else {
                    return false
                }
                return taskDescriptor.modelID != modelID
            }
            .forEach { $0.cancel() }
        let existingTasksByRelativePath = Dictionary(
            uniqueKeysWithValues: tasks.compactMap { task -> (String, URLSessionDownloadTask)? in
                guard let description = task.taskDescription,
                      let taskDescriptor = ModelBackgroundTaskDescriptor(taskDescription: description),
                      taskDescriptor.modelID == modelID else {
                    return nil
                }

                return (taskDescriptor.relativePath, task)
            }
        )

        for artifact in descriptor.artifacts {
            var artifactState = job.artifactState(for: artifact.relativePath)
            if artifactState.phase == .downloaded {
                artifactState.taskIdentifier = nil
                artifactState.errorMessage = nil
                job.setArtifactState(artifactState, for: artifact.relativePath)
                continue
            }

            if let existingTask = existingTasksByRelativePath[artifact.relativePath] {
                existingTask.resume()
                artifactState.phase = .downloading
                artifactState.taskIdentifier = existingTask.taskIdentifier
                artifactState.completedBytes = max(existingTask.countOfBytesReceived, 0)
                artifactState.expectedBytes = existingTask.countOfBytesExpectedToReceive > 0
                    ? existingTask.countOfBytesExpectedToReceive
                    : artifact.progressTotalBytes
                artifactState.errorMessage = nil
                artifactState.updatedAt = .now
                job.setArtifactState(artifactState, for: artifact.relativePath)
                continue
            }

            let taskDescriptor = ModelBackgroundTaskDescriptor(
                modelID: modelID,
                relativePath: artifact.relativePath
            )
            let task = session.downloadTask(with: artifact.remoteURL)
            task.taskDescription = taskDescriptor.taskDescription
            task.resume()

            artifactState.phase = .downloading
            artifactState.taskIdentifier = task.taskIdentifier
            artifactState.completedBytes = 0
            artifactState.expectedBytes = artifact.progressTotalBytes
            artifactState.errorMessage = nil
            artifactState.updatedAt = .now
            job.setArtifactState(artifactState, for: artifact.relativePath)
        }

        job.lastErrorMessage = nil
        job.finalizationState = job.isReadyForFinalization ? .pending : .awaitingDownloads
        try persist(job)
        return job
    }

    func synchronizeWithSystemTasks() async -> ModelBackgroundDownloadJob? {
        guard var job = loadJob() else {
            return nil
        }

        let tasks = await allDownloadTasks()
        let descriptor = DictationModelCatalog.descriptor(for: job.modelID)
        let taskDescriptors = tasks.compactMap { task -> (ModelBackgroundTaskDescriptor, URLSessionDownloadTask)? in
            guard let description = task.taskDescription,
                  let descriptor = ModelBackgroundTaskDescriptor(taskDescription: description) else {
                return nil
            }
            return (descriptor, task)
        }

        let tasksByRelativePath = Dictionary(
            uniqueKeysWithValues: taskDescriptors
                .filter { $0.0.modelID == job.modelID }
                .map { ($0.0.relativePath, $0.1) }
        )
        let activeRelativePaths = Set(tasksByRelativePath.keys)

        for artifact in descriptor.artifacts {
            var artifactState = job.artifactState(for: artifact.relativePath)
            if artifactState.phase == .downloaded {
                artifactState.taskIdentifier = nil
                job.setArtifactState(artifactState, for: artifact.relativePath)
                continue
            }

            if let task = tasksByRelativePath[artifact.relativePath] {
                artifactState.phase = .downloading
                artifactState.taskIdentifier = task.taskIdentifier
                artifactState.completedBytes = max(task.countOfBytesReceived, 0)
                artifactState.expectedBytes = task.countOfBytesExpectedToReceive > 0
                    ? task.countOfBytesExpectedToReceive
                    : artifact.progressTotalBytes
                artifactState.errorMessage = nil
                artifactState.updatedAt = .now
            } else if artifactState.phase == .downloading && !activeRelativePaths.contains(artifact.relativePath) {
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

        do {
            try persist(job)
            return job
        } catch {
            return job
        }
    }

    func markFinalizationInProgress() {
        guard var job = loadJob() else { return }
        job.finalizationState = .inProgress
        job.lastErrorMessage = nil
        try? persist(job)
    }

    func markFinalizationPending() {
        guard var job = loadJob() else { return }
        job.finalizationState = .pending
        job.lastErrorMessage = nil
        try? persist(job)
    }

    func markFinalizationFailed(message: String) {
        guard var job = loadJob() else { return }
        job.finalizationState = .failed
        job.lastErrorMessage = message
        try? persist(job)
    }

    func clearJob() async {
        let tasks = await allDownloadTasks()
        tasks.forEach { $0.cancel() }
        if let job = loadJob() {
            clearStagingArtifacts(for: job.modelID)
        }
        try? jobStore.clear()
        notifyStateChange(with: nil)
    }

    private func synchronizedJob(for modelID: DictationModelID) -> ModelBackgroundDownloadJob {
        if let existingJob = loadJob(), existingJob.modelID == modelID {
            return existingJob
        }

        return ModelBackgroundDownloadJob(modelID: modelID)
    }

    private func persist(_ job: ModelBackgroundDownloadJob) throws {
        try jobStore.save(job)
        notifyStateChange(with: job)
    }

    private func ensureStagingDirectoryExists(for modelID: DictationModelID) throws {
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

    private func allDownloadTasks() async -> [URLSessionDownloadTask] {
        await withCheckedContinuation { continuation in
            session.getAllTasks { tasks in
                continuation.resume(returning: tasks.compactMap { $0 as? URLSessionDownloadTask })
            }
        }
    }

    private func finishBackgroundSessionEventsIfNeeded() {
        completionHandlerLock.lock()
        let completionHandler = backgroundSessionCompletionHandler
        backgroundSessionCompletionHandler = nil
        completionHandlerLock.unlock()
        completionHandler?()
    }

    private func updateJob(
        for taskDescriptor: ModelBackgroundTaskDescriptor,
        mutate: (inout ModelBackgroundDownloadJob, inout ModelBackgroundArtifactState) -> Void
    ) {
        var job = loadJob() ?? ModelBackgroundDownloadJob(modelID: taskDescriptor.modelID)
        guard job.modelID == taskDescriptor.modelID else { return }
        var artifactState = job.artifactState(for: taskDescriptor.relativePath)
        mutate(&job, &artifactState)
        job.setArtifactState(artifactState, for: taskDescriptor.relativePath)
        try? persist(job)
    }
}

extension ModelBackgroundDownloadCoordinator: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let description = downloadTask.taskDescription,
              let taskDescriptor = ModelBackgroundTaskDescriptor(taskDescription: description) else {
            return
        }

        let fallbackExpectedBytes = DictationModelCatalog
            .descriptor(for: taskDescriptor.modelID)
            .artifacts
            .first(where: { $0.relativePath == taskDescriptor.relativePath })?
            .progressTotalBytes

        updateJob(for: taskDescriptor) { _, artifactState in
            artifactState.phase = .downloading
            artifactState.taskIdentifier = downloadTask.taskIdentifier
            artifactState.completedBytes = max(totalBytesWritten, 0)
            artifactState.expectedBytes = totalBytesExpectedToWrite > 0
                ? totalBytesExpectedToWrite
                : fallbackExpectedBytes
            artifactState.errorMessage = nil
            artifactState.updatedAt = .now
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let description = downloadTask.taskDescription,
              let taskDescriptor = ModelBackgroundTaskDescriptor(taskDescription: description),
              let stagedURL = modelLocator.stagedArtifactURL(
                for: taskDescriptor.modelID,
                relativePath: taskDescriptor.relativePath
              ) else {
            return
        }

        do {
            let parentDirectoryURL = stagedURL.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: parentDirectoryURL.path) {
                try fileManager.createDirectory(at: parentDirectoryURL, withIntermediateDirectories: true)
            }
            if fileManager.fileExists(atPath: stagedURL.path) {
                try fileManager.removeItem(at: stagedURL)
            }
            try fileManager.moveItem(at: location, to: stagedURL)

            let fileSize = (try? fileManager.attributesOfItem(atPath: stagedURL.path)[.size] as? NSNumber)?.int64Value ?? 0
            updateJob(for: taskDescriptor) { job, artifactState in
                artifactState.phase = .downloaded
                artifactState.taskIdentifier = nil
                artifactState.completedBytes = fileSize
                artifactState.expectedBytes = max(artifactState.expectedBytes ?? 0, fileSize)
                artifactState.errorMessage = nil
                artifactState.updatedAt = .now
                if job.isReadyForFinalization {
                    job.finalizationState = .pending
                    job.lastErrorMessage = nil
                }
            }
        } catch {
            updateJob(for: taskDescriptor) { job, artifactState in
                artifactState.phase = .failed
                artifactState.taskIdentifier = nil
                artifactState.errorMessage = error.localizedDescription
                artifactState.updatedAt = .now
                job.lastErrorMessage = error.localizedDescription
                job.finalizationState = .failed
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error,
              let description = task.taskDescription,
              let taskDescriptor = ModelBackgroundTaskDescriptor(taskDescription: description) else {
            return
        }

        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else {
            return
        }

        updateJob(for: taskDescriptor) { job, artifactState in
            artifactState.phase = .failed
            artifactState.taskIdentifier = nil
            artifactState.errorMessage = error.localizedDescription
            artifactState.updatedAt = .now
            job.lastErrorMessage = error.localizedDescription
            job.finalizationState = .failed
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        finishBackgroundSessionEventsIfNeeded()
    }
}
