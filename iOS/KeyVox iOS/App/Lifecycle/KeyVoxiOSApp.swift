import SwiftUI
import UIKit
import KeyVoxCore
import KeyVoxPromotions

@main
struct KeyVoxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appLaunchRouteStore: AppLaunchRouteStore
    @StateObject private var audioModeCoordinator: AudioModeCoordinator
    @StateObject private var transcriptionManager: TranscriptionManager
    @StateObject private var ttsManager: TTSManager
    @StateObject private var ttsPurchaseController: TTSPurchaseController
    @StateObject private var keyVoxSpeakIntroController: KeyVoxSpeakIntroController
    @StateObject private var keyVoxVibesPurchaseController: KeyVoxVibesPurchaseController
    @StateObject private var keyVoxVibesIntroController: KeyVoxVibesIntroController
    @StateObject private var ttsPreviewPlayer: TTSPreviewPlayer
    @StateObject private var pocketTTSModelManager: PocketTTSModelManager
    @StateObject private var localRewriteModelManager: LocalRewriteModelManager
    @StateObject private var modelManager: ModelManager
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var onboardingStore: OnboardingStore
    @StateObject private var dictationShortcutSetupIntroController: DictationShortcutSetupIntroController
    @StateObject private var weeklyWordStatsStore: WeeklyWordStatsStore
    @StateObject private var appReviewRequestCoordinator: AppReviewRequestCoordinator
    @StateObject private var appTabRouter: AppTabRouter
    @StateObject private var appUpdateCoordinator: AppUpdateCoordinator
    @StateObject private var promotionCenter: PromotionCenter
    private let appHaptics: AppHaptics
    private let urlRouter: KeyVoxURLRouter
    private let dictionaryStore: DictionaryStore

    init() {
        let services = AppServiceRegistry.shared
        _appLaunchRouteStore = StateObject(wrappedValue: AppLaunchRouteStore.shared)
        _audioModeCoordinator = StateObject(wrappedValue: services.audioModeCoordinator)
        _transcriptionManager = StateObject(wrappedValue: services.transcriptionManager)
        _ttsManager = StateObject(wrappedValue: services.ttsManager)
        _ttsPurchaseController = StateObject(wrappedValue: services.ttsPurchaseController)
        _keyVoxSpeakIntroController = StateObject(wrappedValue: services.keyVoxSpeakIntroController)
        _keyVoxVibesPurchaseController = StateObject(wrappedValue: services.keyVoxVibesPurchaseController)
        _keyVoxVibesIntroController = StateObject(wrappedValue: services.keyVoxVibesIntroController)
        _ttsPreviewPlayer = StateObject(wrappedValue: services.ttsPreviewPlayer)
        _pocketTTSModelManager = StateObject(wrappedValue: services.pocketTTSModelManager)
        _localRewriteModelManager = StateObject(wrappedValue: services.localRewriteModelManager)
        _modelManager = StateObject(wrappedValue: services.modelManager)
        _settingsStore = StateObject(wrappedValue: services.settingsStore)
        _onboardingStore = StateObject(wrappedValue: services.onboardingStore)
        _dictationShortcutSetupIntroController = StateObject(
            wrappedValue: services.dictationShortcutSetupIntroController
        )
        _weeklyWordStatsStore = StateObject(wrappedValue: services.weeklyWordStatsStore)
        _appReviewRequestCoordinator = StateObject(wrappedValue: services.appReviewRequestCoordinator)
        _appTabRouter = StateObject(wrappedValue: services.appTabRouter)
        _appUpdateCoordinator = StateObject(wrappedValue: services.appUpdateCoordinator)
        _promotionCenter = StateObject(wrappedValue: services.promotionCenter)
        appHaptics = services.appHaptics
        urlRouter = services.urlRouter
        dictionaryStore = services.dictionaryStore
        let segmentedControlAppearance = UISegmentedControl.appearance()
        segmentedControlAppearance.selectedSegmentTintColor = .systemIndigo
        segmentedControlAppearance.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.white,
                .font: UIFont.systemFont(ofSize: 15, weight: .regular)
            ],
            for: .normal
        )
        segmentedControlAppearance.setTitleTextAttributes(
            [
                .foregroundColor: UIColor.black,
                .font: UIFont.systemFont(ofSize: 15, weight: .heavy)
            ],
            for: .selected
        )
        configureLegacyBarAppearanceIfNeeded()
        ModelDownloadBackgroundTasks.register()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(\.appHaptics, appHaptics)
                .environmentObject(appLaunchRouteStore)
                .environmentObject(audioModeCoordinator)
                .environmentObject(transcriptionManager)
                .environmentObject(ttsManager)
                .environmentObject(ttsPurchaseController)
                .environmentObject(keyVoxSpeakIntroController)
                .environmentObject(keyVoxVibesPurchaseController)
                .environmentObject(keyVoxVibesIntroController)
                .environmentObject(ttsPreviewPlayer)
                .environmentObject(pocketTTSModelManager)
                .environmentObject(localRewriteModelManager)
                .environmentObject(modelManager)
                .environmentObject(settingsStore)
                .environmentObject(onboardingStore)
                .environmentObject(dictationShortcutSetupIntroController)
                .environmentObject(weeklyWordStatsStore)
                .environmentObject(appReviewRequestCoordinator)
                .environmentObject(appTabRouter)
                .environmentObject(appUpdateCoordinator)
                .environmentObject(promotionCenter)
                .environmentObject(dictionaryStore)
                .onChange(of: scenePhase, initial: true) { _, newPhase in
                    Self.log("scenePhase=\(String(describing: newPhase))")
                    switch newPhase {
                    case .active:
                        let initialRoute = appLaunchRouteStore.consumePendingShortcutRoute()
                            ?? appLaunchRouteStore.consumeInitialURLRoute()
                        if let initialRoute {
                            handle(route: initialRoute, shouldPresentReturnToHost: true)
                        }
                        transcriptionManager.handleAppDidBecomeActive()
                        ttsManager.handleAppDidBecomeActive()
                        pocketTTSModelManager.handleAppDidBecomeActive()
                        localRewriteModelManager.handleAppDidBecomeActive()
                        modelManager.handleAppDidBecomeActive()
                        appUpdateCoordinator.handleAppDidBecomeActive()
                        promotionCenter.refresh()
                        onboardingStore.armPendingKeyboardTourRouteIfNeeded(
                            isKeyboardEnabledInSystemSettings: OnboardingKeyboardAccessProbe.isKeyboardEnabledInSystemSettings()
                        )
                        keyVoxVibesPurchaseController.refreshTrialStateIfNeeded()
                        let isShowingReturnToHost = transcriptionManager.isReturnToHostViewPresented
                            || appLaunchRouteStore.initialURLRoute == .startRecording
                        if isShowingReturnToHost == false,
                           appUpdateCoordinator.activePrompt == nil,
                           dictationShortcutSetupIntroController.wantsPresentationOnEligibleLaunch
                            || dictationShortcutSetupIntroController.hasPresentedThisLaunch {
                            keyVoxSpeakIntroController.markDeferredUntilNextEligibleLaunch()
                            keyVoxSpeakIntroController.cancelPendingPresentation()
                            keyVoxVibesIntroController.markDeferredUntilNextEligibleLaunch()
                            keyVoxVibesIntroController.cancelPendingPresentation()
                            dictationShortcutSetupIntroController.schedulePresentationIfEligible(
                                onboardingStore: onboardingStore
                            )
                        } else if keyVoxVibesIntroController.wantsPresentationOnEligibleLaunch {
                            keyVoxSpeakIntroController.markDeferredUntilNextEligibleLaunch()
                            keyVoxVibesIntroController.handleAppDidBecomeActive(
                                onboardingStore: onboardingStore,
                                isShowingReturnToHost: isShowingReturnToHost
                            )
                        } else {
                            keyVoxSpeakIntroController.handleAppDidBecomeActive(
                                onboardingStore: onboardingStore,
                                isShowingReturnToHost: isShowingReturnToHost
                            )
                        }
                    case .background:
                        transcriptionManager.handleAppDidEnterBackground()
                        ttsManager.handleAppDidEnterBackground()
                        modelManager.handleAppDidEnterBackground()
                        onboardingStore.handleAppDidEnterBackground()
                    case .inactive:
                        ttsManager.handleAppWillResignActive()
                        pocketTTSModelManager.handleAppWillResignActive()
                        localRewriteModelManager.handleAppWillResignActive()
                        modelManager.handleAppWillResignActive()
                    @unknown default:
                        break
                    }
                }
                .onOpenURL { url in
                    if let route = KeyVoxURLRoute(url: url) {
                        Self.log(
                            "onOpenURL route=\(String(describing: route)) shouldPresentReturnToHost=\(String(scenePhase != .active)) scenePhase=\(String(describing: scenePhase))"
                        )
                        handle(
                            route: route,
                            shouldPresentReturnToHost: scenePhase != .active
                        )
                    } else {
                        urlRouter.handle(url: url)
                    }
                }
                .onChange(of: appLaunchRouteStore.routeEventSequence, initial: false) { _, _ in
                    guard scenePhase == .active,
                          let stagedRoute = appLaunchRouteStore.consumeInitialURLRoute() else {
                        return
                    }
                    handle(route: stagedRoute, shouldPresentReturnToHost: false)
                }
        }
    }

    private func handle(route: KeyVoxURLRoute, shouldPresentReturnToHost: Bool) {
        if onboardingStore.shouldShowOnboarding, route.isVibesPresentationRoute {
            Self.log("ignored onboarding route=\(String(describing: route))")
            return
        }

        Self.log(
            "handle route=\(String(describing: route)) shouldPresentReturnToHost=\(String(shouldPresentReturnToHost))"
        )
        if route == .startRecording, shouldPresentReturnToHost {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                transcriptionManager.isReturnToHostViewPresented = true
            }
            appLaunchRouteStore.clearInitialPresentationRoute()
        }

        urlRouter.handle(route: route, shouldPresentReturnToHost: shouldPresentReturnToHost)
    }

    private func configureLegacyBarAppearanceIfNeeded() {
        guard #unavailable(iOS 26.0) else { return }

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()

        let navigationBarAppearance = UINavigationBarAppearance()
        navigationBarAppearance.configureWithDefaultBackground()

        let tabBar = UITabBar.appearance()
        tabBar.standardAppearance = tabBarAppearance
        tabBar.scrollEdgeAppearance = tabBarAppearance

        let navigationBar = UINavigationBar.appearance()
        navigationBar.standardAppearance = navigationBarAppearance
        navigationBar.scrollEdgeAppearance = navigationBarAppearance
        navigationBar.compactAppearance = navigationBarAppearance
    }

    private static func log(_ message: String) {
        #if DEBUG
        NSLog("[KeyVoxApp] %@", message)
        #endif
    }
}

private extension KeyVoxURLRoute {
    var isVibesPresentationRoute: Bool {
        switch self {
        case .openVibes, .openVibesTrialStart, .openVibesModelRecovery:
            return true
        case .startRecording, .stopRecording, .startTTS, .openDictionary, .openSettings:
            return false
        }
    }
}
