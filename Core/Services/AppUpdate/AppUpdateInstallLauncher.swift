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

        let launchDeadline = Date().addingTimeInterval(1)
        while !process.isRunning && Date() < launchDeadline {
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        guard process.isRunning else {
            #if DEBUG
            print("[AppUpdateInstallLauncher] updater.sh exited before install handoff completed.")
            #endif
            throw AppUpdateError.installerLaunchFailed
        }

        let confirmationDeadline = Date().addingTimeInterval(0.2)
        while Date() < confirmationDeadline {
            if !process.isRunning {
                #if DEBUG
                print("[AppUpdateInstallLauncher] updater.sh exited during launch confirmation.")
                #endif
                throw AppUpdateError.installerLaunchFailed
            }
            try await Task.sleep(nanoseconds: 50_000_000)
        }

        NSApplication.shared.terminate(nil)
    }
}
