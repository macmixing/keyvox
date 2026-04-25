import SwiftUI

struct SettingsTabView: View {
    @Environment(\.appHaptics) var appHaptics
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject var ttsPreviewPlayer: TTSPreviewPlayer
    @EnvironmentObject var settingsStore: AppSettingsStore
    @Binding var pendingDeletionConfirmation: SettingsPendingDeletionConfirmation?
    @Binding var pendingDownloadConfirmation: PendingDownloadConfirmation?
    @State var isModelSectionExpanded = false
    @State var modelExpandedContentHeight: CGFloat = 0
    @State var isTTSSectionExpanded = false
    @State var ttsExpandedContentHeight: CGFloat = 0
    @State var isThirdPartyNoticesPresented = false
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
        AppScrollScreen {
            VStack(alignment: .leading, spacing: 16) {
                sessionSection
                speakTimeoutSection
                keyboardSection
                audioSection
                activeModelSection
                ttsSection
                rateAndReviewSection
                supportSection
                restorePurchasesSection
                versionFooter
            }
        }
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

}

#Preview {
    SettingsTabView(
        pendingDeletionConfirmation: .constant(nil),
        pendingDownloadConfirmation: .constant(nil)
    )
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.pocketTTSModelManager)
        .environmentObject(AppServiceRegistry.shared.ttsPurchaseController)
        .environmentObject(AppServiceRegistry.shared.ttsPreviewPlayer)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
}
