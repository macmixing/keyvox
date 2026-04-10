import Foundation

nonisolated enum AppUpdateConfiguration {
    static let appStoreAppID = "6760396964"
    static let refreshInterval: TimeInterval = 21_600

    static var policyManifestURL: URL {
        requiredURL("https://raw.githubusercontent.com/macmixing/keyvox/main/iOS/app-update-policy.json")
    }

    static var appStoreLookupURL: URL {
        requiredURL("https://itunes.apple.com/lookup?id=\(appStoreAppID)")
    }

    static var fallbackAppStoreURL: URL {
        requiredURL("https://apps.apple.com/app/id\(appStoreAppID)")
    }

    private static func requiredURL(_ urlString: String) -> URL {
        guard let url = URL(string: urlString) else {
            fatalError("AppUpdateConfiguration failed to create URL from string: \(urlString)")
        }

        return url
    }
}
