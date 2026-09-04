import Foundation

extension ResumableDownloadTransport: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard let descriptor = taskDescriptor(for: downloadTask) else { return }
        delegate?.resumableDownloadTransport(
            self,
            didWriteDataFor: descriptor,
            taskIdentifier: downloadTask.taskIdentifier,
            totalBytesWritten: totalBytesWritten,
            totalBytesExpectedToWrite: totalBytesExpectedToWrite
        )
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let descriptor = taskDescriptor(for: downloadTask) else { return }
        delegate?.resumableDownloadTransport(
            self,
            didFinishDownloading: descriptor,
            to: location,
            response: downloadTask.response
        )
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let descriptor = taskDescriptor(for: task) else { return }
        let sessionKind: ResumableDownloadSessionKind = session === self.session(for: .foreground)
            ? .foreground
            : .background
        delegate?.resumableDownloadTransport(
            self,
            didComplete: descriptor,
            in: sessionKind,
            error: error
        )
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        finishBackgroundSessionEventsIfNeeded()
    }
}
