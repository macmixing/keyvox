import Combine
import Foundation

@MainActor
final class AppReviewRequestCoordinator: ObservableObject {
    struct Context: Equatable {
        let hasResolvedLaunchContext: Bool
        let isMainInterfacePresented: Bool
        let hasCompetingPresentation: Bool
        let isUpdatePromptStateRefreshing: Bool
        let hasCompletedOnboardingBeforeCurrentLaunch: Bool
        let currentVersion: String?
    }

    private let store: AppReviewRequestStore
    private var latestContext: Context?
    private var isSuppressedForCurrentActivation = false
    private var pendingTask: Task<Void, Never>?
    private var pendingTaskID: UUID?

    init(store: AppReviewRequestStore) {
        self.store = store
    }

    func handleAppDidBecomeActive() {
        isSuppressedForCurrentActivation = false
        latestContext = nil
        cancelPendingRequest()
    }

    func handleAppDidLeaveActive() {
        latestContext = nil
        cancelPendingRequest()
    }

    func evaluate(
        context: Context,
        requestReview: @escaping @MainActor () -> Void
    ) {
        latestContext = context

        guard context.hasResolvedLaunchContext else {
            cancelPendingRequest()
            return
        }

        if context.isUpdatePromptStateRefreshing {
            cancelPendingRequest()
            return
        }

        guard context.isMainInterfacePresented,
              context.hasCompetingPresentation == false else {
            isSuppressedForCurrentActivation = true
            cancelPendingRequest()
            return
        }

        guard isSuppressedForCurrentActivation == false,
              pendingTask == nil,
              let currentVersion = context.currentVersion,
              store.isEligible(
                  currentVersion: currentVersion,
                  hasCompletedOnboardingBeforeCurrentLaunch: context.hasCompletedOnboardingBeforeCurrentLaunch
              ) else {
            return
        }

        scheduleRequest(
            for: currentVersion,
            context: context,
            requestReview: requestReview
        )
    }

    private func scheduleRequest(
        for version: String,
        context: Context,
        requestReview: @escaping @MainActor () -> Void
    ) {
        let taskID = UUID()
        pendingTaskID = taskID
        pendingTask = Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.clearPendingRequest(ifMatching: taskID) }

            try? await Task.sleep(for: .seconds(2))
            guard Task.isCancelled == false,
                  self.latestContext == context,
                  self.isSuppressedForCurrentActivation == false,
                  self.store.isEligible(
                      currentVersion: version,
                      hasCompletedOnboardingBeforeCurrentLaunch: context.hasCompletedOnboardingBeforeCurrentLaunch
                  ) else {
                return
            }

            self.store.markRequested(for: version)
            requestReview()
        }
    }

    private func cancelPendingRequest() {
        pendingTask?.cancel()
        pendingTask = nil
        pendingTaskID = nil
    }

    private func clearPendingRequest(ifMatching taskID: UUID) {
        guard pendingTaskID == taskID else { return }
        pendingTask = nil
        pendingTaskID = nil
    }
}
