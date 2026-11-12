import AppKit
import Combine
import Foundation

enum AppUpdateError: LocalizedError {
    case networkUnavailable
    case applicationsMoveFailed
    case checksumMismatch
    case extractionFailed
    case invalidBundle
    case bundleIdentifierMismatch
    case versionMismatch
    case signatureVerificationFailed
    case releaseUnavailable
    case missingInstallAsset
    case missingInstallerScript
    case installerLaunchFailed

    var errorDescription: String? {
        switch self {
        case .networkUnavailable:
            return String(localized: "Updates are temporarily unavailable.", comment: "Status and error text in the KeyVox update window when the update server cannot be reached.")
        case .applicationsMoveFailed:
            return String(localized: "KeyVox could not move itself into Applications.", comment: "Error message shown in the KeyVox update window when an app update fails. KeyVox is a brand name and stays in English. Applications is the macOS Applications folder; use the name macOS uses in this language.")
        case .checksumMismatch:
            return String(localized: "The downloaded update did not match the expected checksum.", comment: "Error message shown in the KeyVox update window when an app update fails.")
        case .extractionFailed:
            return String(localized: "KeyVox could not unpack the update archive.", comment: "Error message shown in the KeyVox update window when an app update fails. KeyVox is a brand name and stays in English.")
        case .invalidBundle:
            return String(localized: "The downloaded update bundle was not valid.", comment: "Error message shown in the KeyVox update window when an app update fails.")
        case .bundleIdentifierMismatch:
            return String(localized: "The downloaded update did not match this app.", comment: "Error message shown in the KeyVox update window when an app update fails.")
        case .versionMismatch:
            return String(localized: "The downloaded update version did not match the release metadata.", comment: "Error message shown in the KeyVox update window when an app update fails.")
        case .signatureVerificationFailed:
            return String(localized: "The downloaded update could not be verified by macOS.", comment: "Error message shown in the KeyVox update window when an app update fails.")
        case .releaseUnavailable:
            return String(localized: "No update release is available right now.", comment: "Error message shown in the KeyVox update window when an app update fails.")
        case .missingInstallAsset:
            return String(localized: "This release is only available as a manual download.", comment: "Error message shown in the KeyVox update window when an app update fails.")
        case .missingInstallerScript:
            return String(localized: "The updater script could not be found in the app bundle.", comment: "Error message shown in the KeyVox update window when an app update fails.")
        case .installerLaunchFailed:
            return String(localized: "KeyVox could not start the installer.", comment: "Error message shown in the KeyVox update window when an app update fails. KeyVox is a brand name and stays in English.")
        }
    }
}

@MainActor
final class AppUpdateCoordinator: ObservableObject {
    private typealias CoordinatorOperation = @MainActor () async -> Void

    static let shared = AppUpdateCoordinator()

    @Published private(set) var state: AppUpdateState = .idle
    @Published private(set) var releaseInfo: AppReleaseInfo?
    @Published private(set) var progress: Double = 0
    @Published private(set) var downloadedBytes: Int64 = 0
    @Published private(set) var totalBytes: Int64 = 0
    @Published private(set) var statusMessage: String = String(localized: "Check for updates to begin.", comment: "Status text shown in the KeyVox update window before any update check has run.")
    @Published private(set) var failureMessage: String?
    @Published private(set) var currentVersion: String
    @Published private(set) var targetVersion: String?
    @Published private(set) var releaseNotesPreview: String = ""
    @Published private(set) var postUpdateNoticeVersion: String?

    private let service: AppUpdateService
    private let manifestLoader: AppUpdateManifestLoader
    private let downloadService: AppUpdateDownloadService
    private let checksumVerifier: AppUpdateChecksumVerifier
    private let archiveExtractor: AppUpdateArchiveExtractor
    private let bundleVerifier: AppUpdateBundleVerifier
    private let installLauncher: AppUpdateInstallLauncher
    private let applicationsPrereflight: AppUpdateApplicationsPrereflight
    private let cleanupService: AppUpdateCleanupService
    private let noticeService: AppUpdateLaunchNoticeService
    private let paths: AppUpdatePaths
    private let fileManager: FileManager
    private var isResumingInstallAfterApplicationsMove = false
    private var isOperationInFlight = false

    init(bundle: Bundle = .main) {
        let paths = AppUpdatePaths()
        let noticeService = AppUpdateLaunchNoticeService(bundle: bundle)
        self.service = AppUpdateService.shared
        self.manifestLoader = AppUpdateManifestLoader(session: .shared)
        self.downloadService = AppUpdateDownloadService(fileManager: .default)
        self.checksumVerifier = AppUpdateChecksumVerifier()
        self.archiveExtractor = AppUpdateArchiveExtractor(fileManager: .default)
        self.bundleVerifier = AppUpdateBundleVerifier(fileManager: .default)
        self.installLauncher = AppUpdateInstallLauncher(noticeService: noticeService)
        self.applicationsPrereflight = AppUpdateApplicationsPrereflight()
        self.cleanupService = AppUpdateCleanupService(fileManager: .default, paths: paths)
        self.noticeService = noticeService
        self.paths = paths
        self.fileManager = .default
        self.currentVersion = AppUpdateLogic.normalizeVersionTag(
            (bundle.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "Unknown"
        )
    }

    func prepareForLaunch() {
        cleanupService.cleanupStaleArtifacts()
        postUpdateNoticeVersion = noticeService.consumePendingNoticeVersionIfNeeded()
        if postUpdateNoticeVersion != nil {
            AppUpdateDisplayCoordinator.shared.restorePreferredDisplayKeyForResumedUpdate(
                noticeService.pendingNoticePreferredDisplayKey()
            )
        }
        if let resumeContext = applicationsPrereflight.consumeResumeAfterApplicationsMoveContext() {
            service.suppressNextAutomaticUpdatePrompt()
            AppUpdateDisplayCoordinator.shared.restorePreferredDisplayKeyForResumedUpdate(
                resumeContext.preferredDisplayKey
            )
            WindowManager.shared.openUpdateWindow()
            startTrackedOperation {
                await self.resumeInstallAfterApplicationsMove()
            }
        }
    }

    func openWindowForManualCheck() {
        AppUpdateDisplayCoordinator.shared.captureManualCheckDisplay()
        WindowManager.shared.openUpdateWindow()
        startTrackedOperation {
            await self.refreshRelease(userInitiated: true)
        }
    }

    func openWindow(for releaseInfo: AppReleaseInfo?) {
        WindowManager.shared.openUpdateWindow()
        guard !isOperationInFlight else { return }
        if let releaseInfo {
            applyReleaseInfo(releaseInfo, userInitiated: false)
        } else {
            startTrackedOperation {
                await self.refreshRelease(userInitiated: true)
            }
        }
    }

    func dismissPostUpdateNotice() {
        guard let version = postUpdateNoticeVersion else { return }
        noticeService.acknowledge(version: version)
        postUpdateNoticeVersion = nil
        WindowManager.shared.hidePostUpdateNoticeWindow()
        KeyVoxApp.presentLaunchPromptsIfEligibleAfterUpdateGate()
    }

    func primaryAction() {
        switch state {
        case .available:
            startTrackedOperation {
                await self.installAvailableRelease()
            }
        case .manualOnly:
            openReleasePage()
        case .requiresApplicationsInstall:
            moveToApplicationsAndResumeUpdater()
        case .failed, .completed, .idle:
            startTrackedOperation {
                await self.refreshRelease(userInitiated: true)
            }
        default:
            break
        }
    }

    func secondaryAction() {
        switch state {
        case .available, .manualOnly, .failed, .completed, .requiresApplicationsInstall,
                .checking, .downloading, .verifyingChecksum, .extracting,
                .verifyingSignature, .readyToInstall, .installing:
            WindowManager.shared.hideUpdateWindow()
        default:
            break
        }
    }

    var primaryButtonTitle: String {
        switch state {
        case .available:
            return String(localized: "Install Update", comment: "Main button in the KeyVox update window that installs the available update.")
        case .manualOnly:
            return String(localized: "Open Release Page", comment: "Main button in the KeyVox update window that opens the release web page for a manual download.")
        case .requiresApplicationsInstall:
            return String(localized: "Move To Applications", comment: "Main button in the KeyVox update window that moves the app into the Applications folder. Use the name macOS uses for the Applications folder in this language.")
        case .failed, .completed, .idle:
            return String(localized: "Check Again", comment: "Main button in the KeyVox update window that checks for updates again.")
        case .downloading:
            return String(localized: "Downloading...", comment: "Main button in the KeyVox update window while an update is in progress. The update is downloading.")
        case .verifyingChecksum:
            return String(localized: "Verifying...", comment: "Main button in the KeyVox update window while an update is in progress. The download is being verified.")
        case .extracting:
            return String(localized: "Extracting...", comment: "Main button in the KeyVox update window while an update is in progress. The download is being unpacked.")
        case .verifyingSignature:
            return String(localized: "Validating...", comment: "Main button in the KeyVox update window while an update is in progress. The app signature is being validated.")
        case .readyToInstall:
            return String(localized: "Installing...", comment: "Main button in the KeyVox update window while an update is in progress. The update is installing.")
        case .installing:
            return String(localized: "Installing...", comment: "Main button in the KeyVox update window while an update is in progress. The update is installing.")
        case .checking:
            return String(localized: "Checking...", comment: "Main button in the KeyVox update window while an update is in progress. KeyVox is checking for updates.")
        }
    }

    var secondaryButtonTitle: String {
        switch state {
        case .downloading, .verifyingChecksum, .extracting, .verifyingSignature, .readyToInstall, .installing, .checking:
            return String(localized: "Close", comment: "Secondary button in the KeyVox update window that closes the window while an update runs.")
        default:
            return String(localized: "Later", comment: "Secondary button in the KeyVox update window that postpones the update.")
        }
    }

    var canTriggerSecondaryAction: Bool {
        switch state {
        case .downloading, .verifyingChecksum, .extracting, .verifyingSignature, .readyToInstall, .installing:
            return false
        default:
            return true
        }
    }

    var canTriggerPrimaryAction: Bool {
        switch state {
        case .available, .manualOnly, .requiresApplicationsInstall, .failed, .completed, .idle:
            return true
        default:
            return false
        }
    }

    private func refreshUpToDateState() {
        state = .completed
        targetVersion = nil
        failureMessage = nil
        progress = 0
        downloadedBytes = 0
        totalBytes = 0
        releaseNotesPreview = String(localized: "KeyVox \(currentVersion) is currently the latest version.", comment: "Text in the KeyVox update window when no update is available. %@ is the installed app version. KeyVox is a brand name and stays in English.")
        statusMessage = String(localized: "You're up to date.", comment: "Status text shown in the KeyVox update window when no update is available.")
    }

    private func applyReleaseInfo(_ releaseInfo: AppReleaseInfo, userInitiated: Bool) {
        self.releaseInfo = releaseInfo
        targetVersion = releaseInfo.version
        releaseNotesPreview = service.summarizedReleaseBodyForDisplay(releaseInfo.message)
        failureMessage = nil
        progress = 0
        downloadedBytes = 0
        totalBytes = 0

        if !service.shouldOfferUpdateToCurrentVersion(releaseInfo) {
            refreshUpToDateState()
            return
        }

        if releaseInfo.isInstallableInApp {
            if applicationsPrereflight.requiresApplicationsInstall() {
                state = .requiresApplicationsInstall
                statusMessage = String(localized: "Move KeyVox to Applications to use in-app updates.", comment: "Status text shown in the KeyVox update window. KeyVox is a brand name and stays in English. Applications is the macOS Applications folder; use the name macOS uses in this language.")
            } else if isResumingInstallAfterApplicationsMove {
                state = .checking
                statusMessage = String(localized: "Resuming update...", comment: "Status text shown in the KeyVox update window when an update continues after KeyVox moved itself into Applications.")
            } else {
                state = .available
                statusMessage = userInitiated ? String(localized: "Update ready to install.", comment: "Status text shown in the KeyVox update window when an update is ready.") : String(localized: "A new version of KeyVox is available.", comment: "Status text shown in the KeyVox update window when an update is available. KeyVox is a brand name and stays in English.")
            }
        } else {
            state = .manualOnly
            statusMessage = String(localized: "This release needs to be installed manually.", comment: "Status text shown in the KeyVox update window when the update cannot be installed from inside the app.")
        }
    }

    private func openReleasePage() {
        guard let releasePageURL = releaseInfo?.releasePageURL else { return }
        NSWorkspace.shared.open(releasePageURL)
    }

    private func moveToApplicationsAndResumeUpdater() {
        do {
            statusMessage = String(localized: "Moving KeyVox to Applications...", comment: "Status text shown in the KeyVox update window. KeyVox is a brand name and stays in English. Applications is the macOS Applications folder; use the name macOS uses in this language.")
            let destinationURL = try applicationsPrereflight.moveCurrentAppToApplications()
            applicationsPrereflight.stageResumeAfterApplicationsMove(
                preferredDisplayKey: AppUpdateDisplayCoordinator.shared.preferredDisplayKeyForResume
            )
            guard NSWorkspace.shared.open(destinationURL) else {
                NSLog("[AppUpdateCoordinator] Failed to reopen KeyVox from Applications at %@", destinationURL.path)
                applicationsPrereflight.clearResumeAfterApplicationsMove()
                state = .failed
                statusMessage = String(localized: "KeyVox could not reopen from Applications.", comment: "Status text shown in the KeyVox update window. KeyVox is a brand name and stays in English. Applications is the macOS Applications folder; use the name macOS uses in this language.")
                failureMessage = String(localized: "KeyVox was moved to Applications, but macOS could not reopen it. Open KeyVox from Applications and try the update again.", comment: "Error message shown in the KeyVox update window when an app update fails. KeyVox is a brand name and stays in English. Applications is the macOS Applications folder; use the name macOS uses in this language.")
                return
            }
            AppProcessTerminator.terminateImmediately()
        } catch {
            state = .failed
            statusMessage = String(localized: "KeyVox could not move into Applications.", comment: "Status text shown in the KeyVox update window. KeyVox is a brand name and stays in English. Applications is the macOS Applications folder; use the name macOS uses in this language.")
            failureMessage = AppUpdateError.applicationsMoveFailed.errorDescription ?? error.localizedDescription
        }
    }

    private func refreshRelease(userInitiated: Bool) async {
        state = .checking
        statusMessage = String(localized: "Checking for updates...", comment: "Status text shown in the KeyVox update window.")
        failureMessage = nil

        guard let releaseInfo = await service.fetchLatestReleaseInfo() else {
            state = .failed
            statusMessage = String(localized: "Updates are temporarily unavailable.", comment: "Status and error text in the KeyVox update window when the update server cannot be reached.")
            failureMessage = AppUpdateError.releaseUnavailable.errorDescription
            if !userInitiated {
                WindowManager.shared.hideUpdateWindow()
            }
            return
        }

        applyReleaseInfo(releaseInfo, userInitiated: userInitiated)
    }

    private func resumeInstallAfterApplicationsMove() async {
        isResumingInstallAfterApplicationsMove = true
        defer { isResumingInstallAfterApplicationsMove = false }

        await refreshRelease(userInitiated: true)

        guard releaseInfo?.isInstallableInApp == true,
              !applicationsPrereflight.requiresApplicationsInstall() else {
            return
        }

        await installAvailableRelease()
    }

    private func installAvailableRelease() async {
        guard let releaseInfo, let installAssetURL = releaseInfo.installAssetURL else {
            state = .manualOnly
            failureMessage = AppUpdateError.missingInstallAsset.errorDescription
            return
        }
        guard let manifestAssetURL = releaseInfo.manifestAssetURL,
              let installAssetName = releaseInfo.installAssetName else {
            state = .manualOnly
            failureMessage = AppUpdateError.missingInstallAsset.errorDescription
            return
        }

        do {
            if applicationsPrereflight.requiresApplicationsInstall() {
                state = .requiresApplicationsInstall
                statusMessage = String(localized: "Move KeyVox to Applications to use in-app updates.", comment: "Status text shown in the KeyVox update window. KeyVox is a brand name and stays in English. Applications is the macOS Applications folder; use the name macOS uses in this language.")
                return
            }

            let manifest = try await manifestLoader.loadManifest(from: manifestAssetURL)
            guard manifest.assetName == installAssetName else {
                throw AppUpdateError.missingInstallAsset
            }

            let zipURL = paths.zipURL(for: releaseInfo.version, assetName: installAssetName)
            let extractedURL = paths.extractedDirectoryURL(for: releaseInfo.version)
            let paths = self.paths
            try await runBlockingWork {
                try paths.createReleaseDirectoryIfNeeded(for: releaseInfo.version)
            }

            state = .downloading
            statusMessage = String(localized: "Downloading update...", comment: "Status text shown in the KeyVox update window.")
            try await downloadService.download(from: installAssetURL, to: zipURL) { [weak self] written, expected in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.downloadedBytes = written
                    self.totalBytes = expected
                    if expected > 0 {
                        self.progress = Double(written) / Double(expected)
                    }
                }
            }

            state = .verifyingChecksum
            statusMessage = String(localized: "Verifying download...", comment: "Status text shown in the KeyVox update window.")
            let checksumVerifier = self.checksumVerifier
            try await runBlockingWork {
                try checksumVerifier.verify(fileURL: zipURL, expectedSHA256: manifest.sha256)
            }

            state = .extracting
            statusMessage = String(localized: "Preparing update...", comment: "Status text shown in the KeyVox update window while the download is unpacked.")
            let archiveExtractor = self.archiveExtractor
            try await runBlockingWork {
                try archiveExtractor.extract(zipURL: zipURL, to: extractedURL)
            }

            state = .verifyingSignature
            statusMessage = String(localized: "Validating signed app...", comment: "Status text shown in the KeyVox update window while the downloaded app's signature is checked.")
            let bundleVerifier = self.bundleVerifier
            try await runBlockingWork {
                _ = try bundleVerifier.verifyExtractedApp(
                    in: extractedURL,
                    expectedBundleIdentifier: manifest.bundleIdentifier,
                    expectedVersion: releaseInfo.version
                )
            }

            state = .readyToInstall
            statusMessage = String(localized: "Installing KeyVox...", comment: "Status text shown in the KeyVox update window. KeyVox is a brand name and stays in English.")
            try await installLauncher.launchInstall(version: releaseInfo.version, stagedZipURL: zipURL)
        } catch {
            state = .failed
            statusMessage = String(localized: "The update could not be installed.", comment: "Status text shown in the KeyVox update window when the update fails.")
            failureMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    private func startTrackedOperation(_ operation: @escaping CoordinatorOperation) {
        guard !isOperationInFlight else { return }
        // The coordinator intentionally serializes update work so release checks,
        // staging, and install handoff cannot overlap and race shared state.
        isOperationInFlight = true
        Task { @MainActor [weak self] in
            defer { self?.isOperationInFlight = false }
            await operation()
        }
    }

    private func runBlockingWork<T>(_ work: @escaping () throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    continuation.resume(returning: try work())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
