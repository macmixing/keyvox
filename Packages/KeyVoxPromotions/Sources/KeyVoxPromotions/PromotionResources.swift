import Foundation

/// Lets non-bundle hosts point promotions at the unchanged SwiftPM resource bundle.
public enum PromotionResources {
    public enum ConfigurationError: Error { case invalidBundle, alreadyAccessed }

    private static let storage = PromotionResourceBundleStorage()

    public static func configure(bundleURL: URL) throws {
        guard let bundle = Bundle(url: bundleURL) else {
            throw ConfigurationError.invalidBundle
        }
        try storage.configure(bundle)
    }

    static var bundle: Bundle {
        storage.resolve { .module }
    }
}

private final class PromotionResourceBundleStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var configured: Bundle?
    private var accessed = false

    func configure(_ bundle: Bundle) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !accessed else { throw PromotionResources.ConfigurationError.alreadyAccessed }
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
