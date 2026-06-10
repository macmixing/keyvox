import SwiftUI

struct SettingsTabView: View {
    @Environment(\.appHaptics) var appHaptics
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject var localRewriteModelManager: LocalRewriteModelManager
    @EnvironmentObject var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject var keyVoxVibesPurchaseController: KeyVoxVibesPurchaseController
    @EnvironmentObject var ttsPreviewPlayer: TTSPreviewPlayer
    @EnvironmentObject var settingsStore: AppSettingsStore
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
            .onDisappear {
                ttsPreviewPlayer.stop()
            }
            .onChange(of: isTTSSectionExpanded) { _, isExpanded in
                if isExpanded == false {
                    ttsPreviewPlayer.stop()
                }
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

    private var settingsScrollScreen: some View {
        ScrollViewReader { scrollProxy in
            AppScrollScreen {
                VStack(alignment: .leading, spacing: 16) {
                    sessionSection
                    speakTimeoutSection
                    keyboardSection
                    audioSection
                    activeModelSection
                    vibesAISection
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
        .environmentObject(AppTabRouter())
}
