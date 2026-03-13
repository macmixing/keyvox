import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager
    @EnvironmentObject private var weeklyWordStatsStore: iOSWeeklyWordStatsStore

    var body: some View {
        iOSAppScrollScreen {
            VStack(alignment: .leading, spacing: 16) {
                weeklyStatsSection
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
        iOSAppCard {
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
        iOSLastTranscriptionCardView(
            text: transcriptionManager.isRecoveringInterruptedCapture ? nil : transcriptionManager.lastTranscriptionText,
            isLoading: transcriptionManager.isRecoveringInterruptedCapture
        )
    }

    #if DEBUG
    @ViewBuilder
    private var diagnosticsSection: some View {
        iOSAppCard {
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
        .environmentObject(iOSAppServiceRegistry.shared.transcriptionManager)
        .environmentObject(iOSAppServiceRegistry.shared.weeklyWordStatsStore)
}
