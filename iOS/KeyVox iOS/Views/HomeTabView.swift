import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var audioModeCoordinator: AudioModeCoordinator
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @EnvironmentObject private var ttsManager: TTSManager
    @EnvironmentObject private var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @EnvironmentObject private var weeklyWordStatsStore: WeeklyWordStatsStore

    var body: some View {
        AppScrollScreen {
            VStack(alignment: .leading, spacing: 16) {
                weeklyStatsSection
                speakClipboardSection
                lastTranscriptionSection
                #if DEBUG
                diagnosticsSection
                #endif
            }
        }
        .onAppear {
            weeklyWordStatsStore.refreshWeeklyWordStatsIfNeeded()
        }
    }

    @ViewBuilder
    private var weeklyStatsSection: some View {
        AppCard {
            VStack(alignment: .center, spacing: -4) {
                Text("\(weeklyWordStatsStore.combinedWordCount.formatted())")
                    .font(.appFont(65))
                    .fontWeight(.heavy)
                    .foregroundStyle(.yellow)
                    .padding(.top, -20)
                
                Text("Words this week!")
                    .font(.appFont(20))
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(10)
        }
    }

    @ViewBuilder
    private var speakClipboardSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speak Copied Text")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(settingsStore.ttsVoice.displayName)
                            .font(.appFont(15, variant: .light))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: ttsButtonTitle,
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        isEnabled: isTTSButtonEnabled,
                        action: handlePrimaryTTSAction
                    )
                }

                Text(ttsStatusText)
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))

                if let error = ttsManager.lastErrorMessage {
                    Text(error)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                }
            }
        }
    }

    @ViewBuilder
    private var lastTranscriptionSection: some View {
        LastTranscriptionCardView(
            text: transcriptionManager.isRecoveringInterruptedCapture ? nil : transcriptionManager.lastTranscriptionText,
            isLoading: transcriptionManager.isRecoveringInterruptedCapture
        )
    }

    #if DEBUG
    @ViewBuilder
    private var diagnosticsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Diagnostics")
                    .font(.appFont(17))
                    .foregroundStyle(.white)

                Text(statusText)
                    .font(.appFont(12))
                    .foregroundStyle(.secondary)

                if let error = transcriptionManager.lastErrorMessage {
                    Text(error)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
    #endif

    private var statusText: String {
        switch transcriptionManager.state {
        case .idle:
            return "State: idle"
        case .recording:
            return "State: recording"
        case .processingCapture:
            return "State: processingCapture"
        case .transcribing:
            return "State: transcribing"
        }
    }

    private var ttsButtonTitle: String {
        switch pocketTTSModelManager.installState {
        case .notInstalled:
            return "Install"
        case .downloading, .installing:
            return "Installing"
        case .failed:
            return "Repair"
        case .ready:
            return ttsManager.isActive ? "Stop" : "Speak"
        }
    }

    private var ttsStatusText: String {
        switch pocketTTSModelManager.installState {
        case .notInstalled:
            return "Install the playback model to read copied text aloud."
        case .downloading:
            return "Downloading playback model..."
        case .installing:
            return "Installing playback model..."
        case .failed:
            return "Playback model install failed."
        case .ready:
            break
        }

        switch ttsManager.state {
        case .idle:
            return "Read copied text aloud using your selected voice."
        case .preparing:
            return "Preparing playback..."
        case .generating:
            return "Generating speech..."
        case .playing:
            return "Speaking copied text."
        case .finished:
            return "Finished speaking."
        case .error:
            return "Playback failed."
        }
    }

    private var isTTSButtonEnabled: Bool {
        switch pocketTTSModelManager.installState {
        case .downloading, .installing:
            return false
        case .notInstalled, .failed, .ready:
            return true
        }
    }

    private func handlePrimaryTTSAction() {
        switch pocketTTSModelManager.installState {
        case .notInstalled:
            pocketTTSModelManager.downloadModel()
        case .failed:
            pocketTTSModelManager.repairModelIfNeeded()
        case .downloading, .installing:
            break
        case .ready:
            audioModeCoordinator.handleSpeakClipboardFromApp()
        }
    }

}

#Preview {
    HomeTabView()
        .environmentObject(AppServiceRegistry.shared.audioModeCoordinator)
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.ttsManager)
        .environmentObject(AppServiceRegistry.shared.pocketTTSModelManager)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
}
