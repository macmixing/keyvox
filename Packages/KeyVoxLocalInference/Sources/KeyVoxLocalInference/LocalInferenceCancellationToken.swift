import Foundation

final class LocalInferenceCancellationToken: @unchecked Sendable {
    private let lock = NSLock()
    private var isCancelled = false

    func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    func checkCancellation() throws {
        lock.lock()
        let currentValue = isCancelled
        lock.unlock()

        if currentValue {
            throw LocalLanguageModelError.cancelled
        }
    }
}
