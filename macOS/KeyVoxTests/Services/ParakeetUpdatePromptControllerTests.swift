import Foundation
import XCTest
@testable import KeyVox

@MainActor
final class ParakeetUpdatePromptControllerTests: XCTestCase {
    func testOffersUpdateForLegacyInstall() throws {
        try withHarness { harness in
            try harness.writeLegacyInstall()

            harness.controller.presentIfNeeded()

            XCTAssertEqual(harness.presenter.prompts.count, 1)
            XCTAssertNotNil(harness.presenter.prompts.first?.primaryButtonTitle)
            XCTAssertNil(harness.presenter.prompts.first?.progress)
            XCTAssertEqual(harness.presenter.prompts.first?.dismissesOnPrimaryAction, false)
        }
    }

    func testDoesNotOfferUpdateForCurrentInstall() throws {
        try withHarness { harness in
            try ParakeetInstallFixture.writeInstall(
                ParakeetInstallFixture.currentArtifacts,
                at: harness.installRootURL
            )
            harness.downloader.refreshModelStatus()

            harness.controller.presentIfNeeded()

            XCTAssertTrue(harness.presenter.prompts.isEmpty)
        }
    }

    func testOffersUpdateOnlyOncePerLaunch() throws {
        try withHarness { harness in
            try harness.writeLegacyInstall()

            harness.controller.presentIfNeeded()
            harness.controller.presentIfNeeded()

            XCTAssertEqual(harness.presenter.prompts.count, 1)
        }
    }

    func testLaterStopsFutureOffers() throws {
        try withHarness { harness in
            try harness.writeLegacyInstall()
            harness.controller.presentIfNeeded()

            harness.presenter.prompts.first?.onDismiss()
            let nextLaunchController = ParakeetUpdatePromptController(
                downloader: harness.downloader,
                defaults: harness.defaults,
                presenter: harness.presenter
            )
            nextLaunchController.presentIfNeeded()

            XCTAssertEqual(harness.presenter.prompts.count, 1)
        }
    }

    func testDownloadShowsProgressThenFinishedAfterInstallCompletes() throws {
        try withHarness { harness in
            try harness.writeLegacyInstall()
            harness.controller.presentIfNeeded()

            harness.presenter.prompts.first?.onPrimaryAction?()
            harness.downloader.updateDownloadState(
                DictationModelInstallState(
                    isReady: true,
                    isDownloading: true,
                    progress: 0.99,
                    errorMessage: nil,
                    phase: .warmingUp
                ),
                for: .parakeetTdtV3
            )

            XCTAssertEqual(harness.presenter.prompts.last?.progress?.statusText, DictationModelInstallPhase.warmingUp.statusText)

            try FileManager.default.removeItem(at: harness.installRootURL)
            try ParakeetInstallFixture.writeInstall(
                ParakeetInstallFixture.currentArtifacts,
                at: harness.installRootURL
            )
            harness.downloader.updateDownloadState(
                DictationModelInstallState(isReady: true, isDownloading: false, progress: 1, errorMessage: nil),
                for: .parakeetTdtV3
            )

            let finishedPrompt = try XCTUnwrap(harness.presenter.prompts.last)
            XCTAssertNil(finishedPrompt.progress)
            XCTAssertNil(finishedPrompt.primaryButtonTitle)
        }
    }

    func testDownloadFailureOffersRetry() throws {
        try withHarness { harness in
            try harness.writeLegacyInstall()
            harness.controller.presentIfNeeded()

            harness.presenter.prompts.first?.onPrimaryAction?()
            harness.downloader.updateDownloadState(
                DictationModelInstallState(isReady: true, isDownloading: true, progress: 0.4, errorMessage: nil),
                for: .parakeetTdtV3
            )
            harness.downloader.updateDownloadState(
                DictationModelInstallState(isReady: true, isDownloading: false, progress: 0, errorMessage: "failure"),
                for: .parakeetTdtV3
            )

            let failedPrompt = try XCTUnwrap(harness.presenter.prompts.last)
            XCTAssertNil(failedPrompt.progress)
            XCTAssertNotNil(failedPrompt.primaryButtonTitle)
            XCTAssertEqual(failedPrompt.dismissesOnPrimaryAction, false)
        }
    }

    func testDownloadWhileAnotherModelDownloadsExplainsWhy() throws {
        try withHarness { harness in
            try harness.writeLegacyInstall()
            harness.controller.presentIfNeeded()
            harness.downloader.activeDownload = ModelDownloader.ActiveDownload(
                token: UUID(),
                modelID: .whisperBase,
                descriptor: harness.downloader.modelLocator.descriptor(for: .whisperBase)
            )

            harness.presenter.prompts.first?.onPrimaryAction?()

            let blockedPrompt = try XCTUnwrap(harness.presenter.prompts.last)
            XCTAssertEqual(harness.presenter.prompts.count, 2)
            XCTAssertNil(blockedPrompt.progress)
            XCTAssertNotNil(blockedPrompt.primaryButtonTitle)
            XCTAssertFalse(harness.downloader.isDownloading(for: .parakeetTdtV3))
        }
    }

    private func withHarness(_ body: (Harness) throws -> Void) throws {
        try withTemporaryDirectory { dir in
            let suiteName = "ParakeetUpdatePromptControllerTests.\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suiteName)!
            defer { defaults.removePersistentDomain(forName: suiteName) }

            let downloader = ParakeetInstallFixture.makeDownloader(
                in: dir,
                makeDownloadSession: { _ in IdleDownloadSession() }
            )
            let presenter = RecordingPromptPresenter()
            let controller = ParakeetUpdatePromptController(
                downloader: downloader,
                defaults: defaults,
                presenter: presenter
            )

            try body(Harness(downloader: downloader, defaults: defaults, presenter: presenter, controller: controller))
        }
    }

    @MainActor
    private struct Harness {
        let downloader: ModelDownloader
        let defaults: UserDefaults
        let presenter: RecordingPromptPresenter
        let controller: ParakeetUpdatePromptController

        var installRootURL: URL {
            downloader.modelLocator.installRootURL(for: .parakeetTdtV3)
        }

        func writeLegacyInstall() throws {
            try ParakeetInstallFixture.writeInstall(ParakeetInstallFixture.legacyArtifacts, at: installRootURL)
            downloader.refreshModelStatus()
        }
    }
}

private final class IdleDownloadSession: ModelDownloadSessioning {
    private var nextTaskIdentifier = 0

    func downloadTask(with url: URL) -> ModelDownloadTasking {
        nextTaskIdentifier += 1
        return IdleDownloadTask(taskIdentifier: nextTaskIdentifier)
    }
}

private final class IdleDownloadTask: ModelDownloadTasking {
    let taskIdentifier: Int

    init(taskIdentifier: Int) {
        self.taskIdentifier = taskIdentifier
    }

    func resume() {}
}
