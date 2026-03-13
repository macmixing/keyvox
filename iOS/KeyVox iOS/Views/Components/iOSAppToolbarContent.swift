import SwiftUI

struct iOSAppToolbarContent: ToolbarContent {
    let selectedTab: ContainingAppTab

    @EnvironmentObject private var transcriptionManager: iOSTranscriptionManager

    private var isSessionEnabled: Bool {
        transcriptionManager.isSessionActive && !transcriptionManager.sessionDisablePending
    }

    var body: some ToolbarContent {
        if selectedTab == .home {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 12) {
                    iOSLogoBarView(size: 32)
                    Text("KeyVox")
                        .font(.appFont(28))
                        .foregroundStyle(.indigo)
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
                    .tint(.indigo.opacity(0.5))
            } else {
                sessionToggleButton
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .tint(.white.opacity(0.001))
            }
        } else {
            sessionToggleButton
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.circle)
                .controlSize(.small)
                .tint(isSessionEnabled ? .indigo.opacity(0.5) : .gray.opacity(0.25))
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
    }

    private func toggleSession() {
        if isSessionEnabled {
            transcriptionManager.handleDisableSessionCommand()
        } else {
            transcriptionManager.handleEnableSessionCommand()
        }
    }
}
