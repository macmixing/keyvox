import Foundation

struct AppUpdateBundleVerifier {
    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func verifyExtractedApp(
        in directoryURL: URL,
        expectedBundleIdentifier: String,
        expectedVersion: String
    ) throws -> URL {
        let appURL = try locateAppBundle(in: directoryURL)
        guard let bundle = Bundle(url: appURL) else {
            throw AppUpdateError.invalidBundle
        }

        let bundleIdentifier = bundle.bundleIdentifier ?? ""
        guard bundleIdentifier == expectedBundleIdentifier else {
            throw AppUpdateError.bundleIdentifierMismatch
        }

        let version = (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
        let normalizedVersion = AppUpdateLogic.normalizeVersionTag(version)
        guard normalizedVersion == expectedVersion else {
            throw AppUpdateError.versionMismatch
        }

        try verifyCodesign(at: appURL)
        try verifyGatekeeper(at: appURL)
        return appURL
    }

    private func locateAppBundle(in directoryURL: URL) throws -> URL {
        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw AppUpdateError.invalidBundle
        }

        for case let candidate as URL in enumerator {
            if candidate.pathExtension == "app" {
                return candidate
            }
        }

        throw AppUpdateError.invalidBundle
    }

    private func verifyCodesign(at appURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--verify", "--deep", "--strict", appURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppUpdateError.signatureVerificationFailed
        }
    }

    private func verifyGatekeeper(at appURL: URL) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/spctl")
        process.arguments = ["-a", "-t", "exec", appURL.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw AppUpdateError.signatureVerificationFailed
        }
    }
}
