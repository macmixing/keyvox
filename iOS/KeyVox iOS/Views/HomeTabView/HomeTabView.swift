import SwiftUI

struct HomeTabView: View {
    @Environment(\.appHaptics) var appHaptics
    @EnvironmentObject var audioModeCoordinator: AudioModeCoordinator
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @EnvironmentObject var ttsManager: TTSManager
    @EnvironmentObject var pocketTTSModelManager: PocketTTSModelManager
    @EnvironmentObject var ttsPurchaseController: TTSPurchaseController
    @EnvironmentObject var settingsStore: AppSettingsStore
    @EnvironmentObject private var weeklyWordStatsStore: WeeklyWordStatsStore
    @State var showsTTSPreparationSlot = false
    @State var isTTSPreparationVisible = false
    @State var ttsPreparationCollapseTask: Task<Void, Never>?
    @State var showsTTSTranscriptPanelContainer = false
    @State var isTTSTranscriptPanelContentVisible = false
    @State var ttsTranscriptCollapseTask: Task<Void, Never>?
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
        .onDisappear {
            ttsTranscriptCollapseTask?.cancel()
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
}

#Preview {
    HomeTabView()
        .environmentObject(AppServiceRegistry.shared.audioModeCoordinator)
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
        .environmentObject(AppServiceRegistry.shared.ttsManager)
        .environmentObject(AppServiceRegistry.shared.pocketTTSModelManager)
        .environmentObject(AppServiceRegistry.shared.ttsPurchaseController)
        .environmentObject(AppServiceRegistry.shared.settingsStore)
        .environmentObject(AppServiceRegistry.shared.weeklyWordStatsStore)
}
