import AppKit
import Foundation

struct AppUpdateInstallLauncher {
    private let noticeService: AppUpdateLaunchNoticeService

    init(noticeService: AppUpdateLaunchNoticeService = AppUpdateLaunchNoticeService()) {
        self.noticeService = noticeService
    }

    @MainActor
    func launchInstall(
        version: String,
        stagedZipURL: URL,
        installPath: String = Bundle.main.bundleURL.path,
        bundle: Bundle = .main
    ) async throws {
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

        let deadline = Date().addingTimeInterval(1)
        while !process.isRunning && Date() < deadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        guard process.isRunning else {
            #if DEBUG
            print("[AppUpdateInstallLauncher] updater.sh exited before install handoff completed.")
            #endif
            throw AppUpdateError.installerLaunchFailed
        }

        NSApplication.shared.terminate(nil)
    }
}
