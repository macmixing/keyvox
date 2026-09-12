import Foundation

/// Hosts embedding Core outside an application bundle can supply its unchanged resources.
/// Configure once, before the first Core resource access. Ordinary SwiftPM hosts need no setup.
public enum KeyVoxCoreResources {
    public enum ConfigurationError: Error { case invalidBundle, alreadyAccessed }
    private static let storage = ResourceBundleStorage()

    public static func configure(bundleURL: URL) throws {
        guard let bundle = Bundle(url: bundleURL) else { throw ConfigurationError.invalidBundle }
        try storage.configure(bundle)
    }

    static var bundle: Bundle { storage.resolve { .module } }
}
