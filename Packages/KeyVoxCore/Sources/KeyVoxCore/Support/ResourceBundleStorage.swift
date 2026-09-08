import Foundation

final class ResourceBundleStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var configured: Bundle?
    private var accessed = false

    func configure(_ bundle: Bundle) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !accessed else { throw KeyVoxCoreResources.ConfigurationError.alreadyAccessed }
        configured = bundle
    }

    func resolve(default defaultBundle: () -> Bundle) -> Bundle {
        lock.lock()
        accessed = true
        let override = configured
        lock.unlock()
        return override ?? defaultBundle()
    }
}
