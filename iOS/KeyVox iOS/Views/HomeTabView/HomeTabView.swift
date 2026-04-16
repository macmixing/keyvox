import SwiftUI

struct HomeTabView: View {
    private enum TTSStatusTransition {
        static let fadeDuration = 0.2
        static let revealDelayNanoseconds: UInt64 = 200_000_000
    }

    @Environment(\.appHaptics) var appHaptics
    @EnvironmentObject var audioModeCoordinator: AudioModeCoordinator
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @EnvironmentObject var ttsManager: TTSManager
    @EnvironmentObject var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject var settingsStore: AppSettingsStore
    @EnvironmentObject private var weeklyWordStatsStore: WeeklyWordStatsStore
    @EnvironmentObject var keyVoxSpeakIntroController: KeyVoxSpeakIntroController
    @State var showsTTSPreparationSlot = false
    @State var isTTSPreparationSlotExpanded = false
    @State var isTTSPreparationVisible = false
    @State var ttsPreparationRevealToken = UUID()
    @State var ttsPreparationCollapseTask: Task<Void, Never>?
    @State var showsTTSTranscriptPanelContainer = false
    @State var isTTSTranscriptPanelContentVisible = false
    @State var ttsTranscriptRevealTask: Task<Void, Never>?
    @State var ttsTranscriptCollapseTask: Task<Void, Never>?
    @State var hasReachedFastModeBackgroundSafeStateThisPlayback = false
    @State var mountsFastModeBackgroundSafetyWarningRow = false
    @State var showsFastModeBackgroundSafetyWarningRow = false
    @State var mountedTTSWarningText: String?
    @State var showsPrimaryTTSStatusRow = true
    @State var ttsStatusTransitionTask: Task<Void, Never>?
    @StateObject var downloadNetworkMonitor = OnboardingDownloadNetworkMonitor()
    @StateObject var ttsTranscriptCopyFeedback = CopyFeedbackController()
    @AppStorage(
        UserDefaultsKeys.App.isTTSTranscriptExpanded,
        store: SharedPaths.appGroupUserDefaults()
    ) var isTTSTranscriptExpanded = false

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
            syncTTSTranscriptPresentation()
        }
        .onChange(of: shouldShowExpandedTTSTranscriptPanel, initial: true) { _, _ in
            updateTTSTranscriptPresentation()
        }
        .onChange(of: ttsManager.state, initial: true) { _, _ in
            syncFastModeBackgroundSafetyWarningState()
        }
        .onChange(of: ttsManager.isFastModeBackgroundSafe, initial: true) { _, _ in
            syncFastModeBackgroundSafetyWarningState()
        }
        .onChange(of: ttsManager.isReplayingCachedPlayback, initial: true) { _, _ in
            syncFastModeBackgroundSafetyWarningState()
        }
        .onChange(of: ttsManager.isPlaybackPaused, initial: true) { _, _ in
            syncFastModeBackgroundSafetyWarningState()
        }
        .onChange(of: settingsStore.fastPlaybackModeEnabled, initial: true) { _, _ in
            syncFastModeBackgroundSafetyWarningState()
        }
        .onChange(of: ttsManager.warningMessage, initial: true) { _, _ in
            syncTTSStatusRows()
        }
        .onChange(of: showsFastModeBackgroundSafetyWarning, initial: true) { _, _ in
            syncTTSStatusRows()
        }
        .onDisappear {
            ttsPreparationRevealToken = UUID()
            ttsPreparationCollapseTask?.cancel()
            ttsTranscriptRevealTask?.cancel()
            ttsTranscriptCollapseTask?.cancel()
            ttsStatusTransitionTask?.cancel()
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

                Divider()

                TTSBenchmarkDiagnosticsSection()
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

    private func syncFastModeBackgroundSafetyWarningState() {
        let isEligibleFastPlayback =
            settingsStore.fastPlaybackModeEnabled
            && ttsManager.state == .playing
            && ttsManager.isReplayingCachedPlayback == false
            && ttsManager.isPlaybackPaused == false

        guard isEligibleFastPlayback else {
            hasReachedFastModeBackgroundSafeStateThisPlayback = false
            return
        }

        if ttsManager.isFastModeBackgroundSafe {
            hasReachedFastModeBackgroundSafeStateThisPlayback = true
        }
    }

    private func syncTTSStatusRows() {
        ttsStatusTransitionTask?.cancel()

        if let ttsWarningText {
            mountedTTSWarningText = ttsWarningText
            withAnimation(.easeInOut(duration: TTSStatusTransition.fadeDuration)) {
                showsFastModeBackgroundSafetyWarningRow = false
                showsPrimaryTTSStatusRow = false
            }

            ttsStatusTransitionTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: TTSStatusTransition.revealDelayNanoseconds)
                guard Task.isCancelled == false else { return }

                mountsFastModeBackgroundSafetyWarningRow = true
                await Task.yield()

                withAnimation(.easeInOut(duration: TTSStatusTransition.fadeDuration)) {
                    showsFastModeBackgroundSafetyWarningRow = true
                }
            }
            return
        }

        withAnimation(.easeInOut(duration: TTSStatusTransition.fadeDuration)) {
            showsFastModeBackgroundSafetyWarningRow = false
        }

        ttsStatusTransitionTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: TTSStatusTransition.revealDelayNanoseconds)
            guard Task.isCancelled == false else { return }
            mountsFastModeBackgroundSafetyWarningRow = false
            mountedTTSWarningText = nil
            withAnimation(.easeInOut(duration: TTSStatusTransition.fadeDuration)) {
                showsPrimaryTTSStatusRow = true
            }
        }
    }
}

#Preview {
    HomeTabView()
        .environmentObject(AppServiceRegistry.shared.audioModeCoordinator)
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.ttsManager)
        .environmentObject(AppServiceRegistry.shared.ttsBenchmarkRecorder)
        .environmentObject(AppServiceRegistry.shared.pocketTTSModelManager)
        .environmentObject(AppServiceRegistry.shared.ttsPurchaseController)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
        .environmentObject(AppServiceRegistry.shared.keyVoxSpeakIntroController)
}
