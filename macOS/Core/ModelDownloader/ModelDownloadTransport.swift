import Foundation

protocol ModelDownloadTasking {
    var taskIdentifier: Int { get }
    func resume()
}

protocol ModelDownloadSessioning {
    func downloadTask(with url: URL) -> ModelDownloadTasking
}

final class URLSessionDownloadTaskAdapter: ModelDownloadTasking {
    private let task: URLSessionDownloadTask

    init(task: URLSessionDownloadTask) {
        self.task = task
    }

    var taskIdentifier: Int {
        task.taskIdentifier
    }

    func resume() {
        task.resume()
    }
}

final class URLSessionDownloadSessionAdapter: ModelDownloadSessioning {
    private let session: URLSession

    init(configuration: URLSessionConfiguration, delegate: URLSessionDownloadDelegate) {
        self.session = URLSession(
            configuration: configuration,
            delegate: delegate,
            delegateQueue: nil
        )
    }

    func downloadTask(with url: URL) -> ModelDownloadTasking {
        URLSessionDownloadTaskAdapter(task: session.downloadTask(with: url))
    }
}

class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    weak var downloader: ModelDownloader?

    init(downloader: ModelDownloader) {
        self.downloader = downloader
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        downloader?.updateTaskProgress(
            id: downloadTask.taskIdentifier,
            written: totalBytesWritten,
            total: totalBytesExpectedToWrite
        )
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloader?.handleDownloadCompletion(task: downloadTask, location: location)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        downloader?.handleDownloadFailure(task: task, error: error)
    }
}
