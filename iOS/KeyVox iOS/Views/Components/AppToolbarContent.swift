import SwiftUI

struct AppToolbarContent: ToolbarContent {
    let selectedTab: ContainingAppTab

    @EnvironmentObject private var transcriptionManager: TranscriptionManager

    private var isSessionEnabled: Bool {
        transcriptionManager.isSessionActive && !transcriptionManager.sessionDisablePending
    }

    var body: some ToolbarContent {
        if selectedTab == .home {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 12) {
                    LogoBarView(size: 32)
                    Text("KeyVox")
                        .font(.appFont(28))
                        .foregroundStyle(.white)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                sessionToggleView
            }
        }
    }

    @ViewBuilder
    private var sessionToggleView: some View {
        if #available(iOS 26.0, *) {
            if isSessionEnabled {
                sessionToggleButton
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .tint(.yellow.opacity(0.6))
            } else {
                sessionToggleButton
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .tint(.indigo.opacity(0.5))
            }
        } else {
            sessionToggleButton
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .tint(isSessionEnabled ? .yellow.opacity(0.6) : .indigo.opacity(0.5))
        }
    }

    private var sessionToggleButton: some View {
        Button(action: toggleSession) {
            Image("logo-white-ios")
                .resizable()
                .renderingMode(.original)
                .scaledToFit()
                .frame(width: 28, height: 28)
        }
        .accessibilityLabel(isSessionEnabled ? "Disable dictation session" : "Enable dictation session")
    }

    private func toggleSession() {
        if isSessionEnabled {
            transcriptionManager.handleDisableSessionCommand()
        } else {
            transcriptionManager.handleEnableSessionCommand()
        }
    }
}
