import SwiftUI

struct SettingsTabView: View {
    @Environment(\.appHaptics) var appHaptics
    @Environment(\.openURL) var openURL
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject var localRewriteModelManager: LocalRewriteModelManager
    @EnvironmentObject var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject var keyVoxVibesPurchaseController: KeyVoxVibesPurchaseController
    @EnvironmentObject var ttsPreviewPlayer: TTSPreviewPlayer
    @EnvironmentObject var settingsStore: AppSettingsStore
    @EnvironmentObject var dictationShortcutSetupIntroController: DictationShortcutSetupIntroController
    @EnvironmentObject private var keyVoxSpeakIntroController: KeyVoxSpeakIntroController
    @EnvironmentObject private var keyVoxVibesIntroController: KeyVoxVibesIntroController
    @EnvironmentObject private var appTabRouter: AppTabRouter
    @Binding var pendingDeletionConfirmation: SettingsPendingDeletionConfirmation?
    @Binding var pendingDownloadConfirmation: PendingDownloadConfirmation?
    @State var isModelSectionExpanded = false
    @State var modelExpandedContentHeight: CGFloat = 0
    @State var displayedVibesAIInstallState: LocalRewriteModelInstallState?
    @State var isVibesAIInstallContentVisible = false
    @State var vibesAIInstallCollapseTask: Task<Void, Never>?
    @State var vibesAIInstallContentHeight: CGFloat = 0
    @State var isTTSSectionExpanded = false
    @State var ttsExpandedContentHeight: CGFloat = 0
    @State var isThirdPartyNoticesPresented = false
    @State var isDictationShortcutSetupPresented = false
    @State private var handledModelSectionExpansionRequestID: UUID?
    @StateObject var downloadNetworkMonitor = OnboardingDownloadNetworkMonitor()
    
    static let sectionExpansionAnimation = Animation.spring(response: 0.42, dampingFraction: 0.84)
    
    var appVersionBuildText: String? {
        guard
            let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
            !version.isEmpty,
            !build.isEmpty
        else {
            return nil
        }
        
        return "v\(version) (\(build))"
    }

    var body: some View {
        settingsScrollScreen
            .sheet(isPresented: $isThirdPartyNoticesPresented) {
                ThirdPartyNoticesView()
            }
            .fullScreenCover(isPresented: $isDictationShortcutSetupPresented) {
                DictationShortcutSetupBrowsingView(mode: .settingsReference) {
                    isDictationShortcutSetupPresented = false
                }
            }
            .blocksAppReviewRequest(
                isThirdPartyNoticesPresented || isDictationShortcutSetupPresented
            )
            .onDisappear {
                ttsPreviewPlayer.stop()
            }
            .onChange(of: isTTSSectionExpanded) { _, isExpanded in
                if isExpanded == false {
                    ttsPreviewPlayer.stop()
                }
            }
            .onChange(of: isDictationShortcutSetupPresented) { _, isPresented in
                guard isPresented else { return }
                deferAutomaticFeatureIntroductions()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active, isDictationShortcutSetupPresented else { return }
                deferAutomaticFeatureIntroductions()
            }
            .onChange(of: pocketTTSModelManager.sharedModelInstallState, initial: true) { oldValue, newValue in
                let wasReady = {
                    if case .ready = oldValue { return true }
                    return false
                }()
                let isReady = {
                    if case .ready = newValue { return true }
                    return false
                }()

                if wasReady == false && isReady {
                    withAnimation(Self.sectionExpansionAnimation) {
                        isTTSSectionExpanded = true
                    }
                }
            }
    }

    private func deferAutomaticFeatureIntroductions() {
        keyVoxVibesIntroController.markDeferredUntilNextEligibleLaunch()
        keyVoxVibesIntroController.cancelPendingPresentation()
        keyVoxSpeakIntroController.markDeferredUntilNextEligibleLaunch()
        keyVoxSpeakIntroController.cancelPendingPresentation()
    }

    private var settingsScrollScreen: some View {
        ScrollViewReader { scrollProxy in
            AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
                VStack(alignment: .leading, spacing: 16) {
                    sessionSection
                    keyboardSection
                    audioSection
                    activeModelSection
                    vibesAISection
                    speakTimeoutSection
                    ttsSection
                    rateAndReviewSection
                    supportSection
                    helpSection
                    restorePurchasesSection
                    versionFooter
                }
            }
            .onChange(of: appTabRouter.settingsModelSectionExpansionRequestID) { _, requestID in
                handleModelSectionExpansionRequest(requestID, scrollProxy: scrollProxy)
            }
            .onAppear {
                handleModelSectionExpansionRequest(
                    appTabRouter.settingsModelSectionExpansionRequestID,
                    scrollProxy: scrollProxy
                )
            }
        }
    }

    private func handleModelSectionExpansionRequest(_ requestID: UUID?, scrollProxy: ScrollViewProxy) {
        guard let requestID,
              handledModelSectionExpansionRequestID != requestID else {
            return
        }

        handledModelSectionExpansionRequestID = requestID

        withAnimation(Self.sectionExpansionAnimation) {
            isModelSectionExpanded = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(Self.sectionExpansionAnimation) {
                scrollProxy.scrollTo(SettingsScrollTarget.dictationModel, anchor: .top)
            }
        }
    }

}

enum SettingsScrollTarget {
    case dictationModel
}

#Preview {
    SettingsTabView(
        pendingDeletionConfirmation: .constant(nil),
        pendingDownloadConfirmation: .constant(nil)
    )
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.pocketTTSModelManager)
        .environmentObject(AppServiceRegistry.shared.localRewriteModelManager)
        .environmentObject(AppServiceRegistry.shared.ttsPurchaseController)
        .environmentObject(AppServiceRegistry.shared.keyVoxVibesPurchaseController)
        .environmentObject(AppServiceRegistry.shared.ttsPreviewPlayer)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.dictationShortcutSetupIntroController)
        .environmentObject(AppTabRouter())
}
