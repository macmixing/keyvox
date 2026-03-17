import Foundation

final class ModelBackgroundDownloadCoordinator: NSObject {
    typealias StateChangeHandler = @Sendable (ModelBackgroundDownloadJob?) -> Void

    static let sessionIdentifier = "com.cueit.keyvox.model-download.background-session"

    var stateDidChange: StateChangeHandler?

    private let fileManager: FileManager
    private let jobStore: ModelBackgroundDownloadJobStore
    private let modelsDirectoryURLProvider: () -> URL?
    private let stagedGGMLURLProvider: () -> URL?
    private let stagedCoreMLZipURLProvider: () -> URL?
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
        modelsDirectoryURLProvider: @escaping () -> URL?,
        stagedGGMLURLProvider: @escaping () -> URL?,
        stagedCoreMLZipURLProvider: @escaping () -> URL?
    ) {
        self.fileManager = fileManager
        self.jobStore = jobStore
        self.modelsDirectoryURLProvider = modelsDirectoryURLProvider
        self.stagedGGMLURLProvider = stagedGGMLURLProvider
        self.stagedCoreMLZipURLProvider = stagedCoreMLZipURLProvider
    }

    func loadJob() -> ModelBackgroundDownloadJob? {
        jobStore.load()
    }

    func registerBackgroundSessionCompletionHandler(_ completionHandler: @escaping () -> Void) {
        completionHandlerLock.lock()
        backgroundSessionCompletionHandler = completionHandler
        completionHandlerLock.unlock()
    }

    func startOrResumeJob() async throws -> ModelBackgroundDownloadJob {
        try ensureStagingDirectoryExists()
        var job = synchronizedJob()
        let tasks = await allDownloadTasks()
        let existingTasksByKind = Dictionary(
            uniqueKeysWithValues: tasks.compactMap { task -> (ModelBackgroundArtifactKind, URLSessionDownloadTask)? in
                guard let description = task.taskDescription,
                      let kind = ModelBackgroundArtifactKind(rawValue: description) else {
                    return nil
                }
                return (kind, task)
            }
        )

        for kind in ModelBackgroundArtifactKind.allCases {
            var artifact = job.artifactState(for: kind)
            if artifact.phase == .downloaded {
                artifact.taskIdentifier = nil
                artifact.errorMessage = nil
                job.setArtifactState(artifact, for: kind)
                continue
            }

            if let task = existingTasksByKind[kind] {
                task.resume()
                artifact.phase = .downloading
                artifact.taskIdentifier = task.taskIdentifier
                artifact.completedBytes = max(task.countOfBytesReceived, 0)
                artifact.expectedBytes = task.countOfBytesExpectedToReceive > 0 ? task.countOfBytesExpectedToReceive : nil
                artifact.errorMessage = nil
                artifact.updatedAt = .now
                job.setArtifactState(artifact, for: kind)
                continue
            }

            let task = session.downloadTask(with: kind.downloadURL)
            task.taskDescription = kind.taskDescription
            task.resume()
            artifact.phase = .downloading
            artifact.taskIdentifier = task.taskIdentifier
            artifact.completedBytes = 0
            artifact.expectedBytes = nil
            artifact.errorMessage = nil
            artifact.updatedAt = .now
            job.setArtifactState(artifact, for: kind)
        }

        job.lastErrorMessage = nil
        if job.isReadyForFinalization {
            job.finalizationState = .pending
        } else {
            job.finalizationState = .awaitingDownloads
        }
        try persist(job)
        return job
    }

    func synchronizeWithSystemTasks() async -> ModelBackgroundDownloadJob? {
        guard var job = loadJob() else {
            return nil
        }

        let tasks = await allDownloadTasks()
        let taskDescriptions = Set(tasks.compactMap(\.taskDescription))

        for kind in ModelBackgroundArtifactKind.allCases {
            var artifact = job.artifactState(for: kind)
            if artifact.phase == .downloaded {
                artifact.taskIdentifier = nil
                job.setArtifactState(artifact, for: kind)
                continue
            }

            if let task = tasks.first(where: { $0.taskDescription == kind.taskDescription }) {
                artifact.phase = .downloading
                artifact.taskIdentifier = task.taskIdentifier
                artifact.completedBytes = max(task.countOfBytesReceived, 0)
                artifact.expectedBytes = task.countOfBytesExpectedToReceive > 0 ? task.countOfBytesExpectedToReceive : nil
                artifact.errorMessage = nil
                artifact.updatedAt = .now
            } else if artifact.phase == .downloading && !taskDescriptions.contains(kind.taskDescription) {
                artifact.phase = .pending
                artifact.taskIdentifier = nil
                artifact.errorMessage = nil
                artifact.updatedAt = .now
            }

            job.setArtifactState(artifact, for: kind)
        }

        if job.isReadyForFinalization {
            if job.finalizationState != .inProgress {
                job.finalizationState = .pending
            }
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
        try? jobStore.clear()
        clearStagingArtifacts()
        notifyStateChange(with: nil)
    }

    private func synchronizedJob() -> ModelBackgroundDownloadJob {
        if let existingJob = loadJob() {
            return existingJob
        }

        return ModelBackgroundDownloadJob()
    }

    private func persist(_ job: ModelBackgroundDownloadJob) throws {
        try jobStore.save(job)
        notifyStateChange(with: job)
    }

    private func ensureStagingDirectoryExists() throws {
        guard let modelsDirectoryURL = modelsDirectoryURLProvider() else {
            throw CocoaError(.fileNoSuchFile)
        }

        if !fileManager.fileExists(atPath: modelsDirectoryURL.path) {
            try fileManager.createDirectory(at: modelsDirectoryURL, withIntermediateDirectories: true)
        }

        guard let stagingDirectoryURL = SharedPaths.modelDownloadStagingDirectoryURL(fileManager: fileManager) else {
            throw CocoaError(.fileNoSuchFile)
        }
        if !fileManager.fileExists(atPath: stagingDirectoryURL.path) {
            try fileManager.createDirectory(at: stagingDirectoryURL, withIntermediateDirectories: true)
        }
    }

    private func stagedURL(for kind: ModelBackgroundArtifactKind) -> URL? {
        switch kind {
        case .ggml:
            return stagedGGMLURLProvider()
        case .coreMLZip:
            return stagedCoreMLZipURLProvider()
        }
    }

    private func clearStagingArtifacts() {
        if let stagedGGMLURL = stagedGGMLURLProvider(),
           fileManager.fileExists(atPath: stagedGGMLURL.path) {
            try? fileManager.removeItem(at: stagedGGMLURL)
        }
        if let stagedCoreMLZipURL = stagedCoreMLZipURLProvider(),
           fileManager.fileExists(atPath: stagedCoreMLZipURL.path) {
            try? fileManager.removeItem(at: stagedCoreMLZipURL)
        }
        if let stagingDirectoryURL = SharedPaths.modelDownloadStagingDirectoryURL(fileManager: fileManager),
           fileManager.fileExists(atPath: stagingDirectoryURL.path) {
            try? fileManager.removeItem(at: stagingDirectoryURL)
        }
    }

    private func notifyStateChange(with job: ModelBackgroundDownloadJob?) {
        stateDidChange?(job)
    }

    private func allDownloadTasks() async -> [URLSessionDownloadTask] {
        await withCheckedContinuation { continuation in
            session.getAllTasks { tasks in
                let downloadTasks = tasks.compactMap { $0 as? URLSessionDownloadTask }
                continuation.resume(returning: downloadTasks)
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
        for kind: ModelBackgroundArtifactKind,
        mutate: (inout ModelBackgroundDownloadJob, inout ModelBackgroundArtifactState) -> Void
    ) {
        var job = loadJob() ?? ModelBackgroundDownloadJob()
        var artifact = job.artifactState(for: kind)
        mutate(&job, &artifact)
        job.setArtifactState(artifact, for: kind)
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
              let kind = ModelBackgroundArtifactKind(rawValue: description) else {
            return
        }

        updateJob(for: kind) { _, artifact in
            artifact.phase = .downloading
            artifact.taskIdentifier = downloadTask.taskIdentifier
            artifact.completedBytes = max(totalBytesWritten, 0)
            artifact.expectedBytes = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil
            artifact.errorMessage = nil
            artifact.updatedAt = .now
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let description = downloadTask.taskDescription,
              let kind = ModelBackgroundArtifactKind(rawValue: description),
              let stagedURL = stagedURL(for: kind) else {
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
            updateJob(for: kind) { job, artifact in
                artifact.phase = .downloaded
                artifact.taskIdentifier = nil
                artifact.completedBytes = fileSize
                artifact.expectedBytes = max(artifact.expectedBytes ?? 0, fileSize)
                artifact.errorMessage = nil
                artifact.updatedAt = .now
                if job.ggml.isDownloaded && job.coreMLZip.isDownloaded {
                    job.finalizationState = .pending
                    job.lastErrorMessage = nil
                }
            }
        } catch {
            updateJob(for: kind) { job, artifact in
                artifact.phase = .failed
                artifact.taskIdentifier = nil
                artifact.errorMessage = error.localizedDescription
                artifact.updatedAt = .now
                job.lastErrorMessage = error.localizedDescription
                job.finalizationState = .failed
            }
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error,
              let description = task.taskDescription,
              let kind = ModelBackgroundArtifactKind(rawValue: description) else {
            return
        }

        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else {
            return
        }

        updateJob(for: kind) { job, artifact in
            artifact.phase = .failed
            artifact.taskIdentifier = nil
            artifact.errorMessage = error.localizedDescription
            artifact.updatedAt = .now
            job.lastErrorMessage = error.localizedDescription
            job.finalizationState = .failed
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        finishBackgroundSessionEventsIfNeeded()
    }
}
