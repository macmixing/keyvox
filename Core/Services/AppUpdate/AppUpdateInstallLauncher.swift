import AppKit
import Foundation

struct AppUpdateInstallLauncher {
    private let noticeService: AppUpdateLaunchNoticeService

    init(noticeService: AppUpdateLaunchNoticeService = AppUpdateLaunchNoticeService()) {
        self.noticeService = noticeService
    }

    func launchInstall(
        version: String,
        stagedZipURL: URL,
        installPath: String = Bundle.main.bundleURL.path,
        bundle: Bundle = .main
    ) throws {
        guard let scriptPath = bundle.path(forResource: "updater", ofType: "sh") else {
            throw AppUpdateError.missingInstallerScript
        }

        noticeService.stagePendingUpdatedVersion(version)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            scriptPath,
            String(ProcessInfo.processInfo.processIdentifier),
            stagedZipURL.path,
            installPath,
        ]
        try process.run()
        NSApplication.shared.terminate(nil)
    }
}
