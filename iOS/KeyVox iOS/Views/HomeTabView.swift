import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager
    @EnvironmentObject private var weeklyWordStatsStore: iOSWeeklyWordStatsStore

    private var sessionToggleBinding: Binding<Bool> {
        Binding(
            get: { transcriptionManager.isSessionActive && !transcriptionManager.sessionDisablePending },
            set: { isEnabled in
                if isEnabled {
                    transcriptionManager.handleEnableSessionCommand()
                } else {
                    transcriptionManager.handleDisableSessionCommand()
                }
            }
        )
    }

    var body: some View {
        iOSAppScrollScreen {
            VStack(alignment: .leading, spacing: 16) {
                weeklyStatsSection
                sessionSection
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
    private var sessionSection: some View {
        iOSAppCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Session")
                    .font(.appFont(17))
                    .foregroundStyle(.white)

                Toggle(isOn: sessionToggleBinding) {
                    Text("Keep Session Active")
                        .font(.appFont(16))
                        .foregroundStyle(.white)
                }

                Text(sessionStatusText)
                    .font(.appFont(12))
                    .foregroundStyle(.secondary)

                if let expirationDate = transcriptionManager.sessionExpirationDate,
                   transcriptionManager.isSessionActive,
                   !transcriptionManager.sessionDisablePending {
                    Text("Turns off after 5 minutes of idle time (until \(expirationDate.formatted(date: .omitted, time: .shortened))).")
                        .font(.appFont(12))
                        .foregroundStyle(.secondary)
                }
            }
        }
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

    private var sessionStatusText: String {
        if transcriptionManager.sessionDisablePending {
            return "Session: Will turn off after current dictation"
        }
        if transcriptionManager.isSessionActive {
            return "Session: Active"
        }
        return "Session: Inactive"
    }
}

#Preview {
    HomeTabView()
        .environmentObject(iOSAppServiceRegistry.shared.transcriptionManager)
        .environmentObject(iOSAppServiceRegistry.shared.weeklyWordStatsStore)
}
