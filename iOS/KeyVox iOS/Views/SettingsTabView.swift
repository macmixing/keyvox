import SwiftUI
import StoreKit

struct SettingsTabView: View {
    @Environment(\.appHaptics) var appHaptics
    @EnvironmentObject var modelManager: ModelManager
    @EnvironmentObject var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject var ttsVoicePreviewPlayer: TTSVoicePreviewPlayer
    @EnvironmentObject var settingsStore: AppSettingsStore
    @State var pendingDeletionConfirmation: SettingsPendingDeletionConfirmation?
    @State var isModelSectionExpanded = false
    @State var isModelExpandedContentVisible = false
    @State var modelExpandedContentHeight: CGFloat = 0
    @State var isTTSSectionExpanded = false
    @State var isTTSExpandedContentVisible = false
    @State var ttsExpandedContentHeight: CGFloat = 0
    
    private var appVersionBuildText: String? {
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
                keyboardSection
                audioSection
                activeModelSection
                ttsSection
                rateAndReviewSection
                supportSection
                versionFooter
            }
        }
        .task {
            modelManager.refreshStatus()
            pocketTTSModelManager.refreshStatus()
        }
        .onAppear {
            syncModelDisclosurePresentation()
            syncTTSDisclosurePresentation()
        }
        .onDisappear {
            ttsVoicePreviewPlayer.stop()
        }
        .onChange(of: isTTSSectionExpanded) { _, isExpanded in
            if isExpanded == false {
                ttsVoicePreviewPlayer.stop()
            }
        }
        .onChange(of: shouldShowExpandedTTSContent, initial: true) { _, _ in
            updateTTSDisclosurePresentation()
        }
        .onChange(of: shouldShowExpandedModelContent, initial: true) { _, _ in
            updateModelDisclosurePresentation()
        }
        .settingsDeletionConfirmation($pendingDeletionConfirmation, onConfirm: performDeletionConfirmation)
    }

    @ViewBuilder
    private var sessionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.4))
                                .frame(width: 32, height: 32)
                            
                            Image(systemName: "clock")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.yellow)
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Session Timeout")
                                .font(.appFont(18))
                                .foregroundStyle(.white)
                            
                            Text(settingsStore.sessionDisableTiming.displayName)
                                .font(.appFont(17))
                                .foregroundStyle(.yellow)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        Menu {
                            Picker("", selection: $settingsStore.sessionDisableTiming) {
                                ForEach(SessionDisableTiming.allCases) { timing in
                                    Text(timing.displayName).tag(timing)
                                }
                            }
                            .pickerStyle(.inline)
                        } label: {
                            Text("Change")
                                .font(.appFont(16))
                                .foregroundColor(.yellow)
                        }
                        .padding(.top, 2)
                    }
                    
                    Text("Decide when the session turns off")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Divider()
                    .background(.white.opacity(0.4))
                
                SettingsRow(
                    icon: "widget.small",
                    title: "Live Activities",
                    description: "Allow KeyVox to show live activity updates",
                    isOn: $settingsStore.liveActivitiesEnabled
                )
            }
        }
    }

    @ViewBuilder
    private var keyboardSection: some View {
        AppCard {
            SettingsRow(
                icon: "keyboard",
                title: "Keyboard Haptics",
                description: "Get haptic feedback from KeyVox Keyboard",
                isOn: $settingsStore.keyboardHapticsEnabled
            )
        }
    }

    @ViewBuilder
    private var audioSection: some View {
        AppCard {
            SettingsRow(
                icon: "mic.fill",
                title: "Prefer Built-In Microphone",
                description: settingsStore.preferBuiltInMicrophone
                    ? "KeyVox will prefer the built-in microphone whenever one is available."
                    : "KeyVox will use the currently connected input device.",
                isOn: $settingsStore.preferBuiltInMicrophone
            )
        }
    }

    @ViewBuilder
    private var rateAndReviewSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "star.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                    
                    Text("Rate & Review")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    AppActionButton(
                        title: "Rate",
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        action: openAppStoreReview
                    )
                }
                
                Text("Share your experience on the App Store")
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
    }
    
    private func openAppStoreReview() {
        appHaptics.light()
        if #available(iOS 18.0, *) {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                AppStore.requestReview(in: scene)
            }
        } else {
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
                SKStoreReviewController.requestReview(in: scene)
            }
        }
    }

    @ViewBuilder
    private var supportSection: some View {
        AppCard {
            Button(action: openGitHubSponsors) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)
                        
                        Image("github")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundColor(.yellow.opacity(0.8))
                            .frame(width: 32, height: 32)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Support on GitHub")
                            .font(.appFont(18))
                            .foregroundStyle(.white)
                        
                        Text("Support open source development via GitHub Sponsors.")
                            .font(.appFont(15, variant: .light))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Image(systemName: "link")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.yellow)
                }
            }
            .buttonStyle(.plain)
        }
    }
    
    private func openGitHubSponsors() {
        appHaptics.light()
        if let url = URL(string: "https://github.com/sponsors/macmixing/") {
            UIApplication.shared.open(url)
        }
    }

    func performDeletionConfirmation(_ confirmation: SettingsPendingDeletionConfirmation) {
        switch confirmation {
        case .dictationModel(let modelID):
            modelManager.deleteModel(withID: modelID)
        case .sharedTTSModel:
            pocketTTSModelManager.deleteSharedModel()
        case .ttsVoice(let voice):
            pocketTTSModelManager.deleteVoice(voice)
        }
    }
    
    @ViewBuilder
    private var versionFooter: some View {
        if let appVersionBuildText {
            Text(appVersionBuildText)
                .font(.appFont(12))
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.top, 12)
                .padding(.bottom, 12)
        }
    }
}

#Preview {
    SettingsTabView()
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.pocketTTSModelManager)
        .environmentObject(AppServiceRegistry.shared.ttsVoicePreviewPlayer)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
}
