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
            return "Updates are temporarily unavailable."
        case .applicationsMoveFailed:
            return "KeyVox could not move itself into Applications."
        case .checksumMismatch:
            return "The downloaded update did not match the expected checksum."
        case .extractionFailed:
            return "KeyVox could not unpack the update archive."
        case .invalidBundle:
            return "The downloaded update bundle was not valid."
        case .bundleIdentifierMismatch:
            return "The downloaded update did not match this app."
        case .versionMismatch:
            return "The downloaded update version did not match the release metadata."
        case .signatureVerificationFailed:
            return "The downloaded update could not be verified by macOS."
        case .releaseUnavailable:
            return "No update release is available right now."
        case .missingInstallAsset:
            return "This release is only available as a manual download."
        case .missingInstallerScript:
            return "The updater script could not be found in the app bundle."
        case .installerLaunchFailed:
            return "KeyVox could not start the installer."
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
    @Published private(set) var statusMessage: String = "Check for updates to begin."
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
        if applicationsPrereflight.consumeResumeAfterApplicationsMove() {
            service.suppressNextAutomaticUpdatePrompt()
            WindowManager.shared.openUpdateWindow()
            startTrackedOperation {
                await self.resumeInstallAfterApplicationsMove()
            }
        }
    }

    func openWindowForManualCheck() {
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
            return "Install Update"
        case .manualOnly:
            return "Open Release Page"
        case .requiresApplicationsInstall:
            return "Move To Applications"
        case .failed, .completed, .idle:
            return "Check Again"
        case .downloading:
            return "Downloading..."
        case .verifyingChecksum:
            return "Verifying..."
        case .extracting:
            return "Extracting..."
        case .verifyingSignature:
            return "Validating..."
        case .readyToInstall:
            return "Installing..."
        case .installing:
            return "Installing..."
        case .checking:
            return "Checking..."
        }
    }

    var secondaryButtonTitle: String {
        switch state {
        case .downloading, .verifyingChecksum, .extracting, .verifyingSignature, .readyToInstall, .installing, .checking:
            return "Close"
        default:
            return "Later"
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
        releaseNotesPreview = "KeyVox \(currentVersion) is currently the latest version."
        statusMessage = "You're up to date."
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
                statusMessage = "Move KeyVox to Applications to use in-app updates."
            } else if isResumingInstallAfterApplicationsMove {
                state = .checking
                statusMessage = "Resuming update..."
            } else {
                state = .available
                statusMessage = userInitiated ? "Update ready to install." : "A new version of KeyVox is available."
            }
        } else {
            state = .manualOnly
            statusMessage = "This release needs to be installed manually."
        }
    }

    private func openReleasePage() {
        guard let releasePageURL = releaseInfo?.releasePageURL else { return }
        NSWorkspace.shared.open(releasePageURL)
    }

    private func moveToApplicationsAndResumeUpdater() {
        do {
            statusMessage = "Moving KeyVox to Applications..."
            let destinationURL = try applicationsPrereflight.moveCurrentAppToApplications()
            applicationsPrereflight.stageResumeAfterApplicationsMove()
            NSWorkspace.shared.open(destinationURL)
            NSApplication.shared.terminate(nil)
        } catch {
            state = .failed
            statusMessage = "KeyVox could not move into Applications."
            failureMessage = AppUpdateError.applicationsMoveFailed.errorDescription ?? error.localizedDescription
        }
    }

    private func refreshRelease(userInitiated: Bool) async {
        state = .checking
        statusMessage = "Checking for updates..."
        failureMessage = nil

        guard let releaseInfo = await service.fetchLatestReleaseInfo() else {
            state = .failed
            statusMessage = "Updates are temporarily unavailable."
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
                statusMessage = "Move KeyVox to Applications to use in-app updates."
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
            statusMessage = "Downloading update..."
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
            statusMessage = "Verifying download..."
            let checksumVerifier = self.checksumVerifier
            try await runBlockingWork {
                try checksumVerifier.verify(fileURL: zipURL, expectedSHA256: manifest.sha256)
            }

            state = .extracting
            statusMessage = "Preparing update..."
            let archiveExtractor = self.archiveExtractor
            try await runBlockingWork {
                try archiveExtractor.extract(zipURL: zipURL, to: extractedURL)
            }

            state = .verifyingSignature
            statusMessage = "Validating signed app..."
            let bundleVerifier = self.bundleVerifier
            try await runBlockingWork {
                _ = try bundleVerifier.verifyExtractedApp(
                    in: extractedURL,
                    expectedBundleIdentifier: manifest.bundleIdentifier,
                    expectedVersion: releaseInfo.version
                )
            }

            state = .readyToInstall
            statusMessage = "Installing KeyVox..."
            try await installLauncher.launchInstall(version: releaseInfo.version, stagedZipURL: zipURL)
        } catch {
            state = .failed
            statusMessage = "The update could not be installed."
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
