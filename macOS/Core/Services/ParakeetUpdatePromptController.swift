import Combine
import Foundation

/// Offers the Parakeet model update once per launch and walks the update prompt
/// through download, install, and warm-up until the new model is ready.
@MainActor
final class ParakeetUpdatePromptController {
    static let shared = ParakeetUpdatePromptController()
    static let promptID = "parakeet-artifact-update"

    private let modelID: DictationModelID = .parakeetTdtV3
    private let downloader: ModelDownloader
    private let defaults: UserDefaults
    private let presenter: UpdatePromptPresenting
    private var hasPresentedThisLaunch = false
    private var hasObservedActiveInstall = false
    private var lastPresentedProgress: UpdatePromptProgress?
    private var installObservation: AnyCancellable?

    init(
        downloader: ModelDownloader? = nil,
        defaults: UserDefaults = .standard,
        presenter: UpdatePromptPresenting? = nil
    ) {
        self.downloader = downloader ?? .shared
        self.defaults = defaults
        self.presenter = presenter ?? UpdatePromptManager.shared
    }

    func presentIfNeeded() {
        guard hasPresentedThisLaunch == false,
              defaults.string(forKey: UserDefaultsKeys.App.dismissedDictationModelUpdatePromptID) != Self.promptID,
              downloader.activeDownload == nil,
              downloader.requiresArtifactUpdate(for: modelID) else {
            return
        }

        hasPresentedThisLaunch = true
        presenter.show(prompt: ParakeetUpdatePromptContent.offer(
            onDownload: { [weak self] in self?.startUpdate() },
            onLater: { [weak self] in self?.dismissPermanently() }
        ))
    }

    private func startUpdate() {
        hasObservedActiveInstall = false
        lastPresentedProgress = nil
        installObservation = downloader.$modelStates
            .dropFirst()
            .compactMap { [modelID] states in states[modelID] }
            .sink { [weak self] state in
                self?.handleInstallState(state)
            }
        downloader.downloadModel(withID: modelID)
    }

    private func handleInstallState(_ state: DictationModelInstallState) {
        if state.isDownloading {
            hasObservedActiveInstall = true
            presentProgressIfChanged(state)
            return
        }

        if let errorMessage = state.errorMessage {
            finishObservingInstall()
            presenter.show(prompt: ParakeetUpdatePromptContent.failed(
                errorMessage: errorMessage,
                onDownload: { [weak self] in self?.startUpdate() },
                onLater: { [weak self] in self?.dismissPermanently() }
            ))
            return
        }

        // Published states arrive before the downloader stores them, so readiness
        // is read from the delivered state and the installed files.
        guard hasObservedActiveInstall,
              state.isReady,
              downloader.modelLocator.isLegacyParakeetInstall() == false else {
            return
        }

        finishObservingInstall()
        presenter.show(prompt: ParakeetUpdatePromptContent.done())
    }

    private func presentProgressIfChanged(_ state: DictationModelInstallState) {
        let prompt = ParakeetUpdatePromptContent.progress(state)
        guard let progress = prompt.progress else { return }

        let roundedProgress = UpdatePromptProgress(
            value: (progress.value * 100).rounded() / 100,
            statusText: progress.statusText
        )
        guard roundedProgress != lastPresentedProgress else { return }

        lastPresentedProgress = roundedProgress
        presenter.show(prompt: prompt)
    }

    private func finishObservingInstall() {
        installObservation?.cancel()
        installObservation = nil
    }

    private func dismissPermanently() {
        defaults.set(Self.promptID, forKey: UserDefaultsKeys.App.dismissedDictationModelUpdatePromptID)
    }
}
