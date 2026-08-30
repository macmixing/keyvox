import StoreKit
import SwiftUI

struct AppRootView: View {
    private enum RootDestination: Equatable {
        case launchHold
        case returnToHost
        case playbackPreparation
        case onboarding
        case main
    }

    private enum RootOverlayState {
        case hidden
        case visible
    }

    @EnvironmentObject private var appLaunchRouteStore: AppLaunchRouteStore
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @EnvironmentObject private var dictationShortcutSetupIntroController: DictationShortcutSetupIntroController
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @EnvironmentObject private var ttsManager: TTSManager
    @EnvironmentObject private var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject private var keyVoxSpeakIntroController: KeyVoxSpeakIntroController
    @EnvironmentObject private var keyVoxVibesPurchaseController: KeyVoxVibesPurchaseController
    @EnvironmentObject private var keyVoxVibesIntroController: KeyVoxVibesIntroController
    @EnvironmentObject private var appUpdateCoordinator: AppUpdateCoordinator
    @EnvironmentObject private var appReviewRequestCoordinator: AppReviewRequestCoordinator
    @Environment(\.requestReview) private var requestReview
    @Environment(\.scenePhase) private var scenePhase
    @State private var previousDestination: RootDestination?
    @State private var onboardingOverlayState: RootOverlayState = .hidden
    @State private var onboardingOverlayOpacity = 1.0
    @State private var isDescendantBlockingReviewRequest = false

    private var destination: RootDestination {
        if !appLaunchRouteStore.hasResolvedInitialLaunchContext {
            return .launchHold
        }

        if ttsManager.isPlaybackPreparationViewPresented {
            return .playbackPreparation
        }

        if !onboardingStore.shouldSuppressReturnToHostView
            && (
                transcriptionManager.isReturnToHostViewPresented
                    || appLaunchRouteStore.initialURLRoute == .startRecording
            ) {
            return .returnToHost
        }

        return onboardingStore.shouldShowOnboarding ? .onboarding : .main
    }

    var body: some View {
        ZStack {
            if destination == .onboarding || destination == .main || destination == .playbackPreparation {
                MainTabView()

                if onboardingOverlayState == .visible || destination == .onboarding {
                    OnboardingFlowView()
                        .opacity(onboardingOverlayOpacity)
                }

                if destination == .playbackPreparation {
                    PlaybackPreparationView()
                }
            } else {
                switch destination {
                case .launchHold:
                    AppTheme.screenBackground
                        .ignoresSafeArea()
                        .transition(rootTransition)
                case .returnToHost:
                    ReturnToHostView()
                        .transition(rootTransition)
                case .playbackPreparation, .onboarding, .main:
                    EmptyView()
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: {
                    destination == .main
                        && dictationShortcutSetupIntroController.isPresented
                        && ttsPurchaseController.isUnlockSheetPresented == false
                        && keyVoxSpeakIntroController.isPresented == false
                        && keyVoxVibesIntroController.isPresented == false
                        && keyVoxVibesPurchaseController.sheetPresentation == nil
                },
                set: { isPresented in
                    if isPresented == false,
                       dictationShortcutSetupIntroController.isPresented {
                        dismissAutomaticDictationShortcutSetup()
                    }
                }
            )
        ) {
            DictationShortcutSetupBrowsingView(mode: .existingUserIntroduction) {
                dismissAutomaticDictationShortcutSetup()
            }
        }
        .sheet(
            isPresented: Binding(
                get: {
                    destination == .main
                        && dictationShortcutSetupIntroController.isPresented == false
                        && keyVoxSpeakIntroController.isPresented
                        && ttsPurchaseController.isUnlockSheetPresented == false
                        && keyVoxVibesIntroController.isPresented == false
                        && keyVoxVibesPurchaseController.sheetPresentation == nil
                },
                set: { isPresented in
                    if isPresented == false,
                       destination == .main,
                       ttsPurchaseController.isUnlockSheetPresented == false,
                       keyVoxVibesIntroController.isPresented == false,
                       keyVoxVibesPurchaseController.sheetPresentation == nil {
                        keyVoxSpeakIntroController.dismiss()
                    }
                }
            )
        ) {
            KeyVoxSpeakIntroSheetView()
                .environmentObject(keyVoxSpeakIntroController)
                .environmentObject(ttsPurchaseController)
        }
        .sheet(
            isPresented: Binding(
                get: {
                    destination == .main
                        && dictationShortcutSetupIntroController.isPresented == false
                        && keyVoxVibesIntroController.isPresented
                        && keyVoxVibesPurchaseController.sheetPresentation == nil
                },
                set: { isPresented in
                    if isPresented == false,
                       destination == .main,
                       keyVoxVibesPurchaseController.sheetPresentation == nil {
                        keyVoxVibesIntroController.dismiss()
                    }
                }
            )
        ) {
            KeyVoxVibesIntroSheetView()
                .environmentObject(keyVoxVibesIntroController)
                .environmentObject(keyVoxVibesPurchaseController)
        }
        .appUpdatePrompt(activeUpdatePrompt, onUpdate: openUpdate, onLater: dismissOptionalUpdate)
        .onAppReviewRequestBlockingChange { isBlocked in
            isDescendantBlockingReviewRequest = isBlocked
        }
        .onAppear {
            previousDestination = destination
            onboardingOverlayState = destination == .onboarding ? .visible : .hidden
            onboardingOverlayOpacity = 1
            updateKeyVoxSpeakIntroPresentation(for: destination)
        }
        .onChange(of: destination, initial: false) { oldValue, newValue in
            previousDestination = oldValue
            updateKeyVoxSpeakIntroPresentation(for: newValue)

            if newValue == .onboarding {
                onboardingOverlayState = .visible
                onboardingOverlayOpacity = 1
            } else if oldValue == .onboarding && newValue == .main {
                withAnimation(.easeInOut(duration: 0.34)) {
                    onboardingOverlayOpacity = 0
                }

                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(340))
                    if destination == .main {
                        onboardingOverlayState = .hidden
                        onboardingOverlayOpacity = 1
                    }
                }
            } else {
                onboardingOverlayState = .hidden
                onboardingOverlayOpacity = 1
            }

            Task { @MainActor in
                evaluateReviewRequest()
            }
        }
        .onChange(of: onboardingStore.hasCompletedOnboardingThisLaunch, initial: false) { _, newValue in
            guard newValue else { return }
            dictationShortcutSetupIntroController.markHandled()
            keyVoxVibesIntroController.markDeferredUntilNextEligibleLaunch()
            keyVoxVibesIntroController.cancelPendingPresentation()
            keyVoxSpeakIntroController.markDeferredUntilNextEligibleLaunch()
            keyVoxSpeakIntroController.cancelPendingPresentation()
        }
        .onChange(of: appUpdateCoordinator.activePrompt?.id, initial: false) { _, _ in
            updateKeyVoxSpeakIntroPresentation(for: destination)
        }
        .onChange(of: appUpdateCoordinator.isRefreshingPromptState, initial: true) { _, _ in
            evaluateReviewRequest()
        }
        .onChange(of: hasCompetingReviewPresentation, initial: true) { _, _ in
            evaluateReviewRequest()
        }
        .onChange(of: scenePhase, initial: true) { _, newPhase in
            if newPhase == .active {
                appReviewRequestCoordinator.handleAppDidBecomeActive()
                updateKeyVoxSpeakIntroPresentation(for: destination)
                Task { @MainActor in
                    evaluateReviewRequest()
                }
            } else {
                appReviewRequestCoordinator.handleAppDidLeaveActive()
            }
        }
        .animation(rootAnimation, value: destination)
    }

    private var rootTransition: AnyTransition {
        shouldSkipRootTransition ? .identity : .opacity
    }

    private var rootAnimation: Animation? {
        shouldSkipRootTransition ? nil : .easeInOut(duration: 0.34)
    }

    private var shouldSkipRootTransition: Bool {
        if destination == .playbackPreparation {
            return true
        }

        return previousDestination == .launchHold
            && (destination == .onboarding || destination == .main)
    }

    private func updateKeyVoxSpeakIntroPresentation(for destination: RootDestination) {
        if destination == .main,
           onboardingStore.hasCompletedOnboardingThisLaunch == false,
           appUpdateCoordinator.activePrompt == nil {
            if dictationShortcutSetupIntroController.wantsPresentationOnEligibleLaunch
                || dictationShortcutSetupIntroController.hasPresentedThisLaunch {
                keyVoxVibesIntroController.markDeferredUntilNextEligibleLaunch()
                keyVoxVibesIntroController.cancelPendingPresentation()
                keyVoxSpeakIntroController.markDeferredUntilNextEligibleLaunch()
                keyVoxSpeakIntroController.cancelPendingPresentation()
                dictationShortcutSetupIntroController.schedulePresentationIfEligible(
                    onboardingStore: onboardingStore
                )
                return
            }

            if keyVoxVibesIntroController.wantsPresentationOnEligibleLaunch {
                keyVoxSpeakIntroController.markDeferredUntilNextEligibleLaunch()
                keyVoxSpeakIntroController.cancelPendingPresentation()
                if keyVoxVibesIntroController.isAutomaticPresentationEligible {
                    keyVoxVibesIntroController.schedulePresentationIfEligible()
                }
            } else {
                keyVoxVibesIntroController.cancelPendingPresentation()
                keyVoxSpeakIntroController.schedulePresentationIfEligible()
            }
        } else {
            dictationShortcutSetupIntroController.cancelPendingPresentation()
            keyVoxSpeakIntroController.cancelPendingPresentation()
            keyVoxVibesIntroController.cancelPendingPresentation()
        }
    }

    private func dismissAutomaticDictationShortcutSetup() {
        dictationShortcutSetupIntroController.markHandled()
        keyVoxVibesIntroController.markDeferredUntilNextEligibleLaunch()
        keyVoxVibesIntroController.cancelPendingPresentation()
        keyVoxSpeakIntroController.markDeferredUntilNextEligibleLaunch()
        keyVoxSpeakIntroController.cancelPendingPresentation()
    }

    private var activeUpdatePrompt: AppUpdateCoordinator.Prompt? {
        guard destination == .main else { return nil }
        return appUpdateCoordinator.activePrompt
    }

    private func openUpdate() {
        appUpdateCoordinator.openAppStore()
    }

    private func dismissOptionalUpdate() {
        appUpdateCoordinator.dismissOptionalPrompt()
    }

    private var hasCompetingReviewPresentation: Bool {
        isDescendantBlockingReviewRequest
            || appUpdateCoordinator.activePrompt != nil
            || keyVoxSpeakIntroController.isPresented
            || keyVoxSpeakIntroController.wantsPresentationOnEligibleLaunch
            || keyVoxVibesIntroController.isPresented
            || keyVoxVibesIntroController.wantsPresentationOnEligibleLaunch
            || dictationShortcutSetupIntroController.isPresented
            || dictationShortcutSetupIntroController.wantsPresentationOnEligibleLaunch
            || ttsPurchaseController.isUnlockSheetPresented
            || keyVoxVibesPurchaseController.sheetPresentation != nil
            || transcriptionManager.state != .idle
            || ttsManager.isActive
    }

    private var hasCompletedOnboardingBeforeCurrentLaunch: Bool {
        onboardingStore.hasCompletedOnboarding
            && onboardingStore.hasCompletedOnboardingThisLaunch == false
    }

    private func evaluateReviewRequest() {
        guard scenePhase == .active else { return }

        appReviewRequestCoordinator.evaluate(
            context: AppReviewRequestCoordinator.Context(
                hasResolvedLaunchContext: appLaunchRouteStore.hasResolvedInitialLaunchContext,
                isMainInterfacePresented: destination == .main,
                hasCompetingPresentation: hasCompetingReviewPresentation,
                isUpdatePromptStateRefreshing: appUpdateCoordinator.isRefreshingPromptState,
                hasCompletedOnboardingBeforeCurrentLaunch: hasCompletedOnboardingBeforeCurrentLaunch,
                currentVersion: appUpdateCoordinator.currentAppVersion?.rawValue
            ),
            requestReview: {
                requestReview()
            }
        )
    }

}

#Preview {
    AppRootView()
        .environmentObject(AppLaunchRouteStore.shared)
        .environmentObject(AppServiceRegistry.shared.audioModeCoordinator)
        .environmentObject(AppServiceRegistry.shared.appTabRouter)
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.ttsManager)
        .environmentObject(AppServiceRegistry.shared.ttsPurchaseController)
        .environmentObject(AppServiceRegistry.shared.keyVoxSpeakIntroController)
        .environmentObject(AppServiceRegistry.shared.keyVoxVibesPurchaseController)
        .environmentObject(AppServiceRegistry.shared.keyVoxVibesIntroController)
        .environmentObject(AppServiceRegistry.shared.appUpdateCoordinator)
        .environmentObject(AppServiceRegistry.shared.appReviewRequestCoordinator)
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.localRewriteModelManager)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.onboardingStore)
        .environmentObject(AppServiceRegistry.shared.dictationShortcutSetupIntroController)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(AppServiceRegistry.shared.dictionaryStore)
}
