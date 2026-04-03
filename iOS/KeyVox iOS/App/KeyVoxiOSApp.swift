import SwiftUI
import UIKit
import KeyVoxCore

@main
struct KeyVoxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var appLaunchRouteStore: AppLaunchRouteStore
    @StateObject private var audioModeCoordinator: AudioModeCoordinator
    @StateObject private var transcriptionManager: TranscriptionManager
    @StateObject private var ttsManager: TTSManager
    @StateObject private var pocketTTSModelManager: PocketTTSModelManager
    @StateObject private var modelManager: ModelManager
    @StateObject private var settingsStore: AppSettingsStore
    @StateObject private var onboardingStore: OnboardingStore
    @StateObject private var weeklyWordStatsStore: WeeklyWordStatsStore
    private let appHaptics: AppHaptics
    private let urlRouter: KeyVoxURLRouter
    private let dictionaryStore: DictionaryStore

    init() {
        let services = AppServiceRegistry.shared
        _appLaunchRouteStore = StateObject(wrappedValue: AppLaunchRouteStore.shared)
        _audioModeCoordinator = StateObject(wrappedValue: services.audioModeCoordinator)
        _transcriptionManager = StateObject(wrappedValue: services.transcriptionManager)
        _ttsManager = StateObject(wrappedValue: services.ttsManager)
        _pocketTTSModelManager = StateObject(wrappedValue: services.pocketTTSModelManager)
        _modelManager = StateObject(wrappedValue: services.modelManager)
        _settingsStore = StateObject(wrappedValue: services.settingsStore)
        _onboardingStore = StateObject(wrappedValue: services.onboardingStore)
        _weeklyWordStatsStore = StateObject(wrappedValue: services.weeklyWordStatsStore)
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
                .environmentObject(pocketTTSModelManager)
                .environmentObject(modelManager)
                .environmentObject(settingsStore)
                .environmentObject(onboardingStore)
                .environmentObject(weeklyWordStatsStore)
                .environmentObject(dictionaryStore)
                .onChange(of: scenePhase, initial: true) { _, newPhase in
                    switch newPhase {
                    case .active:
                        if let initialRoute = appLaunchRouteStore.consumeInitialURLRoute() {
                            handle(route: initialRoute, shouldPresentReturnToHost: true)
                        }
                        transcriptionManager.handleAppDidBecomeActive()
                        ttsManager.handleAppDidBecomeActive()
                        pocketTTSModelManager.handleAppDidBecomeActive()
                        modelManager.handleAppDidBecomeActive()
                        onboardingStore.armPendingKeyboardTourRouteIfNeeded(
                            isKeyboardEnabledInSystemSettings: OnboardingKeyboardAccessProbe.isKeyboardEnabledInSystemSettings()
                        )
                    case .background:
                        transcriptionManager.handleAppDidEnterBackground()
                        ttsManager.handleAppDidEnterBackground()
                        pocketTTSModelManager.handleAppDidEnterBackground()
                        modelManager.handleAppDidEnterBackground()
                        onboardingStore.handleAppDidEnterBackground()
                    case .inactive:
                        ttsManager.handleAppWillResignActive()
                    @unknown default:
                        break
                    }
                }
                .onOpenURL { url in
                    if let route = KeyVoxURLRoute(url: url) {
                        handle(
                            route: route,
                            shouldPresentReturnToHost: scenePhase != .active
                        )
                    } else {
                        urlRouter.handle(url: url)
                    }
                }
        }
    }

    private func handle(route: KeyVoxURLRoute, shouldPresentReturnToHost: Bool) {
        if route == .startRecording, shouldPresentReturnToHost {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                transcriptionManager.isReturnToHostViewPresented = true
            }
            appLaunchRouteStore.clearInitialPresentationRoute()
        }

        if route == .startTTS, shouldPresentReturnToHost {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                ttsManager.isPlaybackPreparationViewPresented = true
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
}
