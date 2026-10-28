import SwiftUI

struct SettingsTabView: View {
    @Environment(\.appHaptics) var appHaptics
    @Environment(\.openURL) var openURL
    @EnvironmentObject var localRewriteModelManager: LocalRewriteModelManager
    @EnvironmentObject var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject var keyVoxVibesPurchaseController: KeyVoxVibesPurchaseController
    @EnvironmentObject var settingsStore: AppSettingsStore
    @EnvironmentObject private var appTabRouter: AppTabRouter
    @Binding var pendingDeletionConfirmation: SettingsPendingDeletionConfirmation?
    @Binding var pendingDownloadConfirmation: PendingDownloadConfirmation?
    @State var displayedVibesAIInstallState: LocalRewriteModelInstallState?
    @State var isVibesAIInstallContentVisible = false
    @State var vibesAIInstallCollapseTask: Task<Void, Never>?
    @State var vibesAIInstallContentHeight: CGFloat = 0
    @State var isThirdPartyNoticesPresented = false
    @State var isDictationSettingsPresented = false
    @State var dictationModelSectionExpansionRequestID: UUID?
    @State private var handledModelSectionExpansionRequestID: UUID?
    
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
            .navigationDestination(isPresented: $isDictationSettingsPresented) {
                DictationSettingsView(
                    pendingDeletionConfirmation: $pendingDeletionConfirmation,
                    pendingDownloadConfirmation: $pendingDownloadConfirmation,
                    modelSectionExpansionRequestID: dictationModelSectionExpansionRequestID
                )
            }
            .blocksAppReviewRequest(isThirdPartyNoticesPresented)
    }

    private var settingsScrollScreen: some View {
        AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
            VStack(alignment: .leading, spacing: 16) {
                dictationSection
                keyboardSection
                keyVoxSpeakSection
                vibesAISection
                rateAndReviewSection
                supportSection
                helpSection
                restorePurchasesSection
                versionFooter
            }
        }
        .onChange(of: appTabRouter.settingsModelSectionExpansionRequestID) { _, requestID in
            handleModelSectionExpansionRequest(requestID)
        }
        .onAppear {
            handleModelSectionExpansionRequest(appTabRouter.settingsModelSectionExpansionRequestID)
        }
    }

    private func handleModelSectionExpansionRequest(_ requestID: UUID?) {
        guard let requestID,
              handledModelSectionExpansionRequestID != requestID else {
            return
        }

        handledModelSectionExpansionRequestID = requestID
        dictationModelSectionExpansionRequestID = requestID
        isDictationSettingsPresented = true
    }
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
