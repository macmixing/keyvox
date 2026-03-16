import SwiftUI
import UIKit
import KeyVoxCore

@main
struct KeyVoxApp: App {
    @UIApplicationDelegateAdaptor(iOSAppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var transcriptionManager: iOSTranscriptionManager
    @StateObject private var modelManager: iOSModelManager
    @StateObject private var settingsStore: iOSAppSettingsStore
    @StateObject private var onboardingStore: iOSOnboardingStore
    @StateObject private var weeklyWordStatsStore: iOSWeeklyWordStatsStore
    private let urlRouter: KeyVoxURLRouter
    private let dictionaryStore: DictionaryStore

    init() {
        let services = iOSAppServiceRegistry.shared
        _transcriptionManager = StateObject(wrappedValue: services.transcriptionManager)
        _modelManager = StateObject(wrappedValue: services.modelManager)
        _settingsStore = StateObject(wrappedValue: services.settingsStore)
        _onboardingStore = StateObject(wrappedValue: services.onboardingStore)
        _weeklyWordStatsStore = StateObject(wrappedValue: services.weeklyWordStatsStore)
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
        iOSModelDownloadBackgroundTasks.register()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(transcriptionManager)
                .environmentObject(modelManager)
                .environmentObject(settingsStore)
                .environmentObject(onboardingStore)
                .environmentObject(weeklyWordStatsStore)
                .environmentObject(dictionaryStore)
                .onChange(of: scenePhase, initial: true) { _, newPhase in
                    switch newPhase {
                    case .active:
                        transcriptionManager.handleAppDidBecomeActive()
                        modelManager.handleAppDidBecomeActive()
                        onboardingStore.armPendingKeyboardTourRouteIfNeeded()
                    case .background:
                        transcriptionManager.handleAppDidEnterBackground()
                        modelManager.handleAppDidEnterBackground()
                    case .inactive:
                        break
                    @unknown default:
                        break
                    }
                }
                .onOpenURL { url in
                    if let route = KeyVoxURLRoute(url: url), route == .startRecording {
                        var transaction = Transaction()
                        transaction.disablesAnimations = true
                        withTransaction(transaction) {
                            transcriptionManager.isReturnToHostViewPresented = true
                        }
                    }
                    urlRouter.handle(url: url)
                }
        }
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
