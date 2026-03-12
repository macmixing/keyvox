import Foundation

struct AppUpdateDownloadService {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func download(
        from url: URL,
        to destinationURL: URL,
        progress: @escaping @Sendable (Int64, Int64) -> Void
    ) async throws {
        try fileManager.createDirectory(at: destinationURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fileManager.fileExists(atPath: destinationURL.path) {
            try fileManager.removeItem(at: destinationURL)
        }

        let delegate = AppUpdateDownloadDelegate()
        delegate.onProgress = progress

        let configuration = URLSessionConfiguration.default
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 60 * 30
        let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)

        defer {
            session.finishTasksAndInvalidate()
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            var hasResumed = false
            delegate.onFinish = { result in
                guard !hasResumed else { return }
                hasResumed = true

                switch result {
                case .success(let location):
                    do {
                        try fileManager.moveItem(at: location, to: destinationURL)
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let task = session.downloadTask(with: url)
            task.resume()
        }
    }
}
