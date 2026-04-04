import SwiftUI

struct AppToolbarContent: ToolbarContent {
    let selectedTab: ContainingAppTab

    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @State private var previousIsSessionEnabled: Bool?
    @State private var pendingToolbarToggleTarget: Bool?
    @State private var previousIsFastModeEnabled: Bool?
    @State private var pendingFastModeToggleTarget: Bool?

    private var isSessionEnabled: Bool {
        transcriptionManager.isSessionActive && !transcriptionManager.sessionDisablePending
    }

    var body: some ToolbarContent {
        if selectedTab == .home {
            ToolbarItem(placement: .navigationBarLeading) {
                fastModeToggleView
            }

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
        Group {
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
        .onAppear {
            previousIsSessionEnabled = isSessionEnabled
        }
        .onChange(of: isSessionEnabled, initial: false) { _, newValue in
            if pendingToolbarToggleTarget == newValue,
               let event = SessionToggleHapticsDecision.event(
                previousIsEnabled: previousIsSessionEnabled,
                currentIsEnabled: newValue
            ) {
                appHaptics.emit(event)
            }

            if pendingToolbarToggleTarget == newValue {
                pendingToolbarToggleTarget = nil
            } else if pendingToolbarToggleTarget != nil {
                pendingToolbarToggleTarget = nil
            }

            previousIsSessionEnabled = newValue
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
            pendingToolbarToggleTarget = false
            transcriptionManager.handleDisableSessionCommand()
        } else {
            pendingToolbarToggleTarget = true
            transcriptionManager.handleEnableSessionCommand()
        }
    }

    @ViewBuilder
    private var fastModeToggleView: some View {
        Group {
            if #available(iOS 26.0, *) {
                if settingsStore.fastPlaybackModeEnabled {
                    fastModeToggleButton
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        .tint(.yellow.opacity(0.6))
                } else {
                    fastModeToggleButton
                        .buttonStyle(.glassProminent)
                        .buttonBorderShape(.circle)
                        .controlSize(.small)
                        .tint(.indigo.opacity(0.5))
                }
            } else {
                fastModeToggleButton
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.circle)
                    .controlSize(.small)
                    .tint(settingsStore.fastPlaybackModeEnabled ? .yellow.opacity(0.6) : .indigo.opacity(0.5))
            }
        }
        .onAppear {
            previousIsFastModeEnabled = settingsStore.fastPlaybackModeEnabled
        }
        .onChange(of: settingsStore.fastPlaybackModeEnabled, initial: false) { _, newValue in
            if pendingFastModeToggleTarget == newValue,
               let event = SessionToggleHapticsDecision.event(
                previousIsEnabled: previousIsFastModeEnabled,
                currentIsEnabled: newValue
            ) {
                appHaptics.emit(event)
            }

            if pendingFastModeToggleTarget == newValue {
                pendingFastModeToggleTarget = nil
            } else if pendingFastModeToggleTarget != nil {
                pendingFastModeToggleTarget = nil
            }

            previousIsFastModeEnabled = newValue
        }
    }

    private var fastModeToggleButton: some View {
        Button(action: toggleFastMode) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
        }
        .accessibilityLabel(settingsStore.fastPlaybackModeEnabled ? "Disable fast playback" : "Enable fast playback")
    }

    private func toggleFastMode() {
        if settingsStore.fastPlaybackModeEnabled {
            pendingFastModeToggleTarget = false
        } else {
            pendingFastModeToggleTarget = true
        }
        settingsStore.fastPlaybackModeEnabled.toggle()
    }
}
