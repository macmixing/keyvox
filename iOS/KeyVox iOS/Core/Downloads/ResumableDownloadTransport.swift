import Foundation

enum ResumableDownloadSessionKind: Sendable, Equatable {
    case foreground
    case background
}

protocol ResumableDownloadTransportDelegate: AnyObject {
    func resumableDownloadTransport(
        _ transport: ResumableDownloadTransport,
        prepareDownloadsFor sessionKind: ResumableDownloadSessionKind,
        resumeDataByArtifactID: [String: Data]
    ) async -> [String: Data]

    func resumableDownloadTransport(
        _ transport: ResumableDownloadTransport,
        didWriteDataFor descriptor: ResumableDownloadTaskDescriptor,
        taskIdentifier: Int,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    )

    func resumableDownloadTransport(
        _ transport: ResumableDownloadTransport,
        didFinishDownloading descriptor: ResumableDownloadTaskDescriptor,
        to location: URL,
        response: URLResponse?
    )

    func resumableDownloadTransport(
        _ transport: ResumableDownloadTransport,
        didComplete descriptor: ResumableDownloadTaskDescriptor,
        in sessionKind: ResumableDownloadSessionKind,
        error: Error?
    )
}

final class ResumableDownloadTransport: NSObject {
    private let sessionIdentifier: String
    private let sharedContainerIdentifier: String
    private let lifecycleLock = NSLock()
    private let completionHandlerLock = NSLock()

    weak var delegate: ResumableDownloadTransportDelegate?
    var appIsActive = false
    var isTransitioning = false
    private var pendingResumeDataByArtifactID: [String: Data] = [:]
    private var backgroundSessionCompletionHandler: (() -> Void)?

    private lazy var backgroundSession: URLSession = {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        configuration.sharedContainerIdentifier = sharedContainerIdentifier
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        configuration.isDiscretionary = false
        return URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    }()

    private lazy var foregroundSession: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: nil)
    }()

    init(
        sessionIdentifier: String,
        sharedContainerIdentifier: String,
        delegate: ResumableDownloadTransportDelegate
    ) {
        self.sessionIdentifier = sessionIdentifier
        self.sharedContainerIdentifier = sharedContainerIdentifier
        self.delegate = delegate
    }

    func registerBackgroundSessionCompletionHandler(_ completionHandler: @escaping () -> Void) {
        completionHandlerLock.lock()
        backgroundSessionCompletionHandler = completionHandler
        completionHandlerLock.unlock()
        _ = backgroundSession
    }

    func session(for kind: ResumableDownloadSessionKind) -> URLSession {
        switch kind {
        case .foreground:
            foregroundSession
        case .background:
            backgroundSession
        }
    }

    func downloadTasks(in kind: ResumableDownloadSessionKind) async -> [URLSessionDownloadTask] {
        await withCheckedContinuation { continuation in
            session(for: kind).getAllTasks { tasks in
                continuation.resume(
                    returning: tasks.compactMap { task in
                        guard task.state != .completed else { return nil }
                        return task as? URLSessionDownloadTask
                    }
                )
            }
        }
    }

    func deduplicatedTasksByArtifactID(
        from tasks: [URLSessionDownloadTask],
        jobID: UUID
    ) -> [String: URLSessionDownloadTask] {
        var result: [String: URLSessionDownloadTask] = [:]
        for task in tasks {
            guard let descriptor = taskDescriptor(for: task), descriptor.jobID == jobID else { continue }
            if result[descriptor.artifactID] == nil {
                result[descriptor.artifactID] = task
            } else {
                task.cancel()
            }
        }
        return result
    }

    func taskDescriptor(for task: URLSessionTask) -> ResumableDownloadTaskDescriptor? {
        task.taskDescription.flatMap(ResumableDownloadTaskDescriptor.init(encoded:))
    }

    func shouldUseBackgroundSession(
        jobID: UUID,
        existingBackgroundTasks: [URLSessionDownloadTask]
    ) -> Bool {
        if existingBackgroundTasks.contains(where: { taskDescriptor(for: $0)?.jobID == jobID }) {
            return true
        }

        return withLifecycleLock {
            !appIsActive || isTransitioning
        }
    }

    func isReadyForForegroundScheduling() -> Bool {
        withLifecycleLock {
            appIsActive && !isTransitioning
        }
    }

    func takePendingResumeData() -> [String: Data] {
        withLifecycleLock {
            let resumeData = pendingResumeDataByArtifactID
            pendingResumeDataByArtifactID.removeAll()
            return resumeData
        }
    }

    func storePendingResumeData(_ resumeData: [String: Data]) {
        withLifecycleLock {
            pendingResumeDataByArtifactID = resumeData
        }
    }

    func cancelAllTasks() async {
        let backgroundTasks = await downloadTasks(in: .background)
        let foregroundTasks = await downloadTasks(in: .foreground)
        (backgroundTasks + foregroundTasks).forEach { $0.cancel() }
        storePendingResumeData([:])
    }

    func cancelAllTasksWithoutWaiting() {
        backgroundSession.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        foregroundSession.getAllTasks { tasks in
            tasks.forEach { $0.cancel() }
        }
        storePendingResumeData([:])
    }

    func finishBackgroundSessionEventsIfNeeded() {
        completionHandlerLock.lock()
        let completionHandler = backgroundSessionCompletionHandler
        backgroundSessionCompletionHandler = nil
        completionHandlerLock.unlock()
        completionHandler?()
    }

    func withLifecycleLock<T>(_ operation: () -> T) -> T {
        lifecycleLock.lock()
        defer { lifecycleLock.unlock() }
        return operation()
    }
}
