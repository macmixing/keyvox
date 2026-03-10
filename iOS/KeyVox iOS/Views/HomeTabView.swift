import SwiftUI

struct HomeTabView: View {
    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                sessionSection
                #if DEBUG
                diagnosticsSection
                #endif
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Session")
                .font(.headline)

            Toggle(
                "Keep Session Active",
                isOn: Binding(
                    get: { transcriptionManager.isSessionActive && !transcriptionManager.sessionDisablePending },
                    set: { isEnabled in
                        if isEnabled {
                            transcriptionManager.handleEnableSessionCommand()
                        } else {
                            transcriptionManager.handleDisableSessionCommand()
                        }
                    }
                )
            )

            Text(sessionStatusText)
                .font(.footnote)
                .foregroundStyle(.secondary)

            if let expirationDate = transcriptionManager.sessionExpirationDate,
               transcriptionManager.isSessionActive,
               !transcriptionManager.sessionDisablePending {
                Text("Turns off after 5 minutes of idle time (until \(expirationDate.formatted(date: .omitted, time: .shortened))).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    #if DEBUG
    @ViewBuilder
    private var diagnosticsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Diagnostics")
                .font(.headline)

            Text(statusText)
                .font(.footnote.monospaced())

            if let error = transcriptionManager.lastErrorMessage {
                Text(error)
                    .font(.footnote.monospaced())
                    .foregroundStyle(.red)
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
}
