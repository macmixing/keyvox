import SwiftUI
import StoreKit

struct SettingsTabView: View {
    @EnvironmentObject private var modelManager: ModelManager
    @EnvironmentObject private var settingsStore: AppSettingsStore

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: 16) {
                sessionSection
                keyboardSection
                audioSection
                rateAndReviewSection
                supportSection
                #if DEBUG
                modelSection
                #endif
            }
        }
        .task {
            modelManager.refreshStatus()
        }
    }

    @ViewBuilder
    private var sessionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(AppTheme.accent.opacity(0.2))
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
                    }
                    
                    Text("Decide when the session turns off")
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                }
                
                Divider()
                    .background(.white.opacity(0.2))
                
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
        if let url = URL(string: "https://github.com/sponsors/macmixing/") {
            UIApplication.shared.open(url)
        }
    }

    @ViewBuilder
    private var modelSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.2))
                            .frame(width: 32, height: 32)
                        
                        Image(systemName: "cpu")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }
                    
                    Text("Model")
                        .font(.appFont(18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    switch modelManager.installState {
                    case .notInstalled:
                        AppActionButton(
                            title: "Download Model",
                            style: .primary,
                            size: .compact,
                            fontSize: 15,
                            action: modelManager.downloadModel
                        )
                    case .downloading, .installing:
                        EmptyView()
                    case .ready:
                        AppActionButton(
                            title: "Delete Model",
                            style: .destructive,
                            size: .compact,
                            fontSize: 15,
                            action: modelManager.deleteModel
                        )
                    case .failed:
                        AppActionButton(
                            title: "Repair Model",
                            style: .primary,
                            size: .compact,
                            fontSize: 15,
                            action: modelManager.repairModelIfNeeded
                        )
                    }
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(modelManager.installState.statusText)
                        .font(.appFont(14, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                    
                    if let error = modelManager.errorMessage {
                        Text(error)
                            .font(.appFont(12))
                            .foregroundStyle(.red)
                    }
                    
                    if case .downloading = modelManager.installState {
                        if let actionText = modelManager.installState.actionText {
                            Text(actionText)
                                .font(.appFont(12))
                                .foregroundStyle(.secondary)
                        }
                    } else if case .installing = modelManager.installState {
                        if let actionText = modelManager.installState.actionText {
                            Text(actionText)
                                .font(.appFont(12))
                                .foregroundStyle(.secondary)
                        }
                    } else if case .failed = modelManager.installState {
                        AppActionButton(
                            title: "Delete Model",
                            style: .destructive,
                            size: .compact,
                            fontSize: 15,
                            action: modelManager.deleteModel
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    SettingsTabView()
        .environmentObject(AppServiceRegistry.shared.modelManager)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
}
