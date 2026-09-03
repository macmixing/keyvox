import Foundation

final class PocketTTSBackgroundDownloadCoordinator: NSObject {
    static let sessionIdentifier = "com.cueit.keyvox.speak-download.background-session"

    var stateDidChange: (@Sendable (PocketTTSBackgroundDownloadJob?) -> Void)?

    private let fileManager: FileManager
    private let jobStore: PocketTTSBackgroundDownloadJobStore
    private let stagingRootProvider: (PocketTTSInstallTarget) throws -> URL
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
        jobStore: PocketTTSBackgroundDownloadJobStore,
        stagingRootProvider: @escaping (PocketTTSInstallTarget) throws -> URL
    ) {
        self.fileManager = fileManager
        self.jobStore = jobStore
        self.stagingRootProvider = stagingRootProvider
    }

    func loadJob() -> PocketTTSBackgroundDownloadJob? {
        jobStore.load()
    }

    func registerBackgroundSessionCompletionHandler(_ completionHandler: @escaping () -> Void) {
        completionHandlerLock.lock()
        backgroundSessionCompletionHandler = completionHandler
        completionHandlerLock.unlock()
    }

    func startOrResumeJob(_ requestedJob: PocketTTSBackgroundDownloadJob) async throws {
        var job = loadJob().flatMap { $0.id == requestedJob.id ? $0 : nil } ?? requestedJob
        let stagingRootURL = try stagingRootProvider(job.target)
        try fileManager.createDirectory(at: stagingRootURL, withIntermediateDirectories: true)
        try persist(job)

        let tasks = await allDownloadTasks()
        tasks.filter { taskDescriptor(for: $0)?.jobID != job.id }.forEach { $0.cancel() }
        let existingTasks = deduplicatedTasksByRelativePath(from: tasks, jobID: job.id)

        for artifact in job.artifacts {
            var state = job.artifactState(for: artifact.relativePath)
            if state.phase == .downloaded {
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

            normalizeQueuedArtifacts(
                in: &job,
                activeRelativePath: artifact.relativePath,
                existingTasks: existingTasks
            )

            let task: URLSessionDownloadTask
            if let existingTask = existingTasks[artifact.relativePath] {
                task = existingTask
                state.completedBytes = max(existingTask.countOfBytesReceived, 0)
                state.expectedBytes = existingTask.countOfBytesExpectedToReceive > 0
                    ? existingTask.countOfBytesExpectedToReceive
                    : artifact.expectedByteCount
            } else {
                task = session.downloadTask(with: artifact.remoteURL)
                task.taskDescription = TaskDescriptor(jobID: job.id, relativePath: artifact.relativePath).encoded
                task.earliestBeginDate = state.retryNotBefore
                state.completedBytes = 0
                state.expectedBytes = artifact.expectedByteCount
            }

            state.phase = .downloading
            state.taskIdentifier = task.taskIdentifier
            state.errorMessage = nil
            state.updatedAt = .now
            job.setArtifactState(state, for: artifact.relativePath)
            job.lastErrorMessage = nil
            job.finalizationState = .awaitingDownloads
            try persist(job)
            task.resume()
            return
        }

        job.lastErrorMessage = nil
        job.finalizationState = .pending
        try persist(job)
    }

    func synchronizeWithSystemTasks() async -> PocketTTSBackgroundDownloadJob? {
        guard var job = loadJob() else { return nil }
        let tasks = await allDownloadTasks()
        let tasksByRelativePath = deduplicatedTasksByRelativePath(from: tasks, jobID: job.id)

        for artifact in job.artifacts {
            var state = job.artifactState(for: artifact.relativePath)
            if state.phase == .downloaded { continue }
            if let task = tasksByRelativePath[artifact.relativePath] {
                state.phase = .downloading
                state.taskIdentifier = task.taskIdentifier
                state.completedBytes = max(task.countOfBytesReceived, 0)
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
        try? persist(job)
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
        let tasks = await allDownloadTasks()
        tasks.forEach { $0.cancel() }
        try? jobStore.clear()
        stateDidChange?(nil)
    }

    func cancelAndClearJob() {
        session.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        try? jobStore.clear()
        stateDidChange?(nil)
    }

    private func normalizeQueuedArtifacts(
        in job: inout PocketTTSBackgroundDownloadJob,
        activeRelativePath: String,
        existingTasks: [String: URLSessionDownloadTask]
    ) {
        for (relativePath, task) in existingTasks where relativePath != activeRelativePath {
            task.cancel()
            var state = job.artifactState(for: relativePath)
            guard state.phase != .downloaded else { continue }
            state.phase = .pending
            state.taskIdentifier = nil
            state.completedBytes = 0
            state.updatedAt = .now
            job.setArtifactState(state, for: relativePath)
        }
    }

    private func allDownloadTasks() async -> [URLSessionDownloadTask] {
        await withCheckedContinuation { continuation in
            session.getAllTasks { tasks in
                continuation.resume(
                    returning: tasks.compactMap { task in
                        guard task.state != .completed else { return nil }
                        return task as? URLSessionDownloadTask
                    }
                )
            }
        }
    }

    private func deduplicatedTasksByRelativePath(
        from tasks: [URLSessionDownloadTask],
        jobID: UUID
    ) -> [String: URLSessionDownloadTask] {
        var result: [String: URLSessionDownloadTask] = [:]
        for task in tasks {
            guard let descriptor = taskDescriptor(for: task), descriptor.jobID == jobID else { continue }
            if result[descriptor.relativePath] == nil {
                result[descriptor.relativePath] = task
            } else {
                task.cancel()
            }
        }
        return result
    }

    private func taskDescriptor(for task: URLSessionTask) -> TaskDescriptor? {
        task.taskDescription.flatMap(TaskDescriptor.init(encoded:))
    }

    private func stagedArtifactURL(stagingRootURL: URL, relativePath: String) throws -> URL {
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

    private func persist(_ job: PocketTTSBackgroundDownloadJob) throws {
        try jobStore.save(job)
        stateDidChange?(job)
    }

    private func updateLoadedJob(_ mutate: (inout PocketTTSBackgroundDownloadJob) -> Void) {
        guard var job = loadJob() else { return }
        mutate(&job)
        job.updatedAt = .now
        try? persist(job)
    }

    private func finishBackgroundSessionEventsIfNeeded() {
        completionHandlerLock.lock()
        let completionHandler = backgroundSessionCompletionHandler
        backgroundSessionCompletionHandler = nil
        completionHandlerLock.unlock()
        completionHandler?()
    }
}

extension PocketTTSBackgroundDownloadCoordinator: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let descriptor = taskDescriptor(for: downloadTask) else { return }
        updateArtifact(for: descriptor) { state, artifact in
            state.phase = .downloading
            state.taskIdentifier = downloadTask.taskIdentifier
            state.completedBytes = max(totalBytesWritten, 0)
            state.expectedBytes = totalBytesExpectedToWrite > 0
                ? totalBytesExpectedToWrite
                : artifact.expectedByteCount
            state.retryNotBefore = nil
            state.errorMessage = nil
            state.updatedAt = .now
        }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let descriptor = taskDescriptor(for: downloadTask),
              let job = loadJob(), job.id == descriptor.jobID else { return }

        do {
            guard let response = downloadTask.response as? HTTPURLResponse else {
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
                        NSLocalizedDescriptionKey: "Speak download failed with HTTP \(response.statusCode) for \(descriptor.relativePath).",
                    ]
                )
            }
            let stagingRootURL = try stagingRootProvider(job.target)
            let destinationURL = try stagedArtifactURL(
                stagingRootURL: stagingRootURL,
                relativePath: descriptor.relativePath
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

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let descriptor = taskDescriptor(for: task) else { return }
        guard let error else {
            resumeQueuedDownloadIfNeeded()
            return
        }
        let nsError = error as NSError
        guard !(nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled) else { return }
        markArtifactFailed(for: descriptor, error: error)
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        finishBackgroundSessionEventsIfNeeded()
    }

    private func updateArtifact(
        for descriptor: TaskDescriptor,
        mutate: (inout PocketTTSBackgroundArtifactState, PocketTTSBackgroundArtifact) -> Void
    ) {
        guard var job = loadJob(), job.id == descriptor.jobID,
              let artifact = job.artifacts.first(where: { $0.relativePath == descriptor.relativePath }) else {
            return
        }
        var state = job.artifactState(for: descriptor.relativePath)
        mutate(&state, artifact)
        job.setArtifactState(state, for: descriptor.relativePath)
        if job.isReadyForFinalization {
            job.finalizationState = .pending
            job.lastErrorMessage = nil
        }
        try? persist(job)
    }

    private func markArtifactFailed(for descriptor: TaskDescriptor, error: Error) {
        #if DEBUG
        NSLog(
            "[PocketTTSBackgroundDownloadCoordinator] Download failed for %@: %@",
            descriptor.relativePath,
            error.localizedDescription
        )
        #endif
        updateArtifact(for: descriptor) { state, _ in
            state.phase = .failed
            state.taskIdentifier = nil
            state.retryNotBefore = nil
            state.errorMessage = error.localizedDescription
            state.updatedAt = .now
        }
        updateLoadedJob {
            $0.finalizationState = .failed
            $0.lastErrorMessage = error.localizedDescription
        }
    }

    private func markArtifactWaitingForRateLimitRetry(
        for descriptor: TaskDescriptor,
        response: HTTPURLResponse
    ) {
        let retryDate = rateLimitRetryDate(from: response)
        let retryDelay = max(Int(retryDate.timeIntervalSinceNow.rounded(.up)), 1)
        #if DEBUG
        NSLog(
            "[PocketTTSBackgroundDownloadCoordinator] HTTP 429 for %@. Retrying after %d seconds.",
            descriptor.relativePath,
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

    private func resumeQueuedDownloadIfNeeded() {
        guard let job = loadJob(), job.finalizationState != .failed else { return }
        Task { [weak self] in
            try? await self?.startOrResumeJob(job)
        }
    }
}

private struct TaskDescriptor {
    let jobID: UUID
    let relativePath: String

    nonisolated var encoded: String? {
        let encodedPath = Data(relativePath.utf8).base64EncodedString()
        return jobID.uuidString + "::" + encodedPath
    }

    nonisolated init(jobID: UUID, relativePath: String) {
        self.jobID = jobID
        self.relativePath = relativePath
    }

    nonisolated init?(encoded: String) {
        let components = encoded.components(separatedBy: "::")
        guard components.count == 2,
              let jobID = UUID(uuidString: components[0]),
              let pathData = Data(base64Encoded: components[1]),
              let relativePath = String(data: pathData, encoding: .utf8) else {
            return nil
        }
        self.jobID = jobID
        self.relativePath = relativePath
    }
}
