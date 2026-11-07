import Foundation

/// Lets non-bundle hosts point the language package at its unchanged SwiftPM resource bundle.
/// Configure once, before the first resource access. Ordinary SwiftPM hosts need no setup.
public enum KeyVoxLinguisticsResources {
    public enum ConfigurationError: Error { case invalidBundle, alreadyAccessed }

    private static let storage = LinguisticsResourceBundleStorage()

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

private final class LinguisticsResourceBundleStorage: @unchecked Sendable {
    private let lock = NSLock()
    private var configured: Bundle?
    private var accessed = false

    func configure(_ bundle: Bundle) throws {
        lock.lock()
        defer { lock.unlock() }
        guard !accessed else { throw KeyVoxLinguisticsResources.ConfigurationError.alreadyAccessed }
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
