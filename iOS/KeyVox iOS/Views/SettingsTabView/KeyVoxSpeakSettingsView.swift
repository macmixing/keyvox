import SwiftUI

/// KeyVox Speak's settings, opened from the KeyVox Speak row in Settings: the speak timeout,
/// then the KeyVox Speak engine and voices card.
struct KeyVoxSpeakSettingsView: View {
    @Environment(\.appHaptics) var appHaptics
    @EnvironmentObject var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject var ttsPreviewPlayer: TTSPreviewPlayer
    @EnvironmentObject var settingsStore: AppSettingsStore
    @Binding var pendingDeletionConfirmation: SettingsPendingDeletionConfirmation?
    @Binding var pendingDownloadConfirmation: PendingDownloadConfirmation?
    @State var isTTSSectionExpanded = false
    @State var ttsExpandedContentHeight: CGFloat = 0
    @StateObject var downloadNetworkMonitor = OnboardingDownloadNetworkMonitor()

    var body: some View {
        AppScrollScreen(additionalTopContentInset: AppScreenContentInset.tabPageTop) {
            VStack(alignment: .leading, spacing: 16) {
                speakTimeoutSection
                ttsSection
            }
        }
        .navigationTitle(KeyVoxSpeakSettingsCopy.screenTitle)
        .navigationBarTitleDisplayMode(.inline)
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
                withAnimation(SettingsTabView.sectionExpansionAnimation) {
                    isTTSSectionExpanded = true
                }
            }
        }
    }
}
