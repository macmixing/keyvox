import SwiftUI
import UIKit

private struct OnboardingStepButton {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
}

struct OnboardingSetupScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var modelManager: ModelManager
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @StateObject private var downloadNetworkMonitor: OnboardingDownloadNetworkMonitor
    @StateObject private var microphonePermissionController: OnboardingMicrophonePermissionController
    @StateObject private var keyboardAccessProbe: OnboardingKeyboardAccessProbe

    @MainActor
    init(
        downloadNetworkMonitor: OnboardingDownloadNetworkMonitor? = nil,
        microphonePermissionController: OnboardingMicrophonePermissionController? = nil,
        keyboardAccessProbe: OnboardingKeyboardAccessProbe? = nil
    ) {
        let resolvedDownloadNetworkMonitor = downloadNetworkMonitor ?? OnboardingDownloadNetworkMonitor()
        let resolvedMicrophonePermissionController = microphonePermissionController ?? OnboardingMicrophonePermissionController()
        let resolvedKeyboardAccessProbe = keyboardAccessProbe ?? OnboardingKeyboardAccessProbe()

        _downloadNetworkMonitor = StateObject(wrappedValue: resolvedDownloadNetworkMonitor)
        _microphonePermissionController = StateObject(wrappedValue: resolvedMicrophonePermissionController)
        _keyboardAccessProbe = StateObject(wrappedValue: resolvedKeyboardAccessProbe)
    }

    var body: some View {
        AppScrollScreen(scrollDisabled: true) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Set up KeyVox")
                    .font(.appFont(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.leading)

                modelRequirementRow
                microphoneRequirementRow
                keyboardRequirementRow
            }
            .padding(.bottom, 24)
        }
        .task {
            refreshState()
        }
        .onChange(of: scenePhase, initial: false) { _, newPhase in
            guard newPhase == .active else { return }
            refreshState()
        }
    }

    @ViewBuilder
    private var modelRequirementRow: some View {
        OnboardingStepRow(
            isCompleted: modelManager.installState == .ready,
            stepNumber: 1,
            title: "AI Model Setup",
            description: modelStepDescription,
            buttonTitle: modelStepButton?.title,
            isButtonEnabled: modelStepButton?.isEnabled ?? true,
            action: modelStepButton?.action,
            trailingContent: {
                if let progress = modelDownloadProgress {
                    Text("\(Int(progress * 100))%")
                        .font(.appFont(11))
                        .foregroundStyle(.yellow)
                }
            },
            extraContent: {
                VStack(alignment: .leading, spacing: 8) {
                    if let progress = modelDownloadProgress {
                        ModelDownloadProgress(progress: progress, showLabel: false)
                    } else if let error = modelManager.errorMessage {
                        Text(error)
                            .font(.appFont(10, variant: .light))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    if shouldShowCellularModelWarning {
                        Text("We recommend Wi-Fi for this download.")
                            .font(.appFont(12))
                            .foregroundStyle(.yellow)
                    }
                }
            }
        )
    }

    private var microphoneRequirementRow: some View {
        OnboardingStepRow(
            isCompleted: microphonePermissionController.status == .granted,
            stepNumber: 2,
            title: "Microphone Access",
            description: "KeyVox needs to hear you to transcribe.",
            buttonTitle: microphoneStepButton?.title,
            isButtonEnabled: microphoneStepButton?.isEnabled ?? true,
            action: microphoneStepButton?.action
        )
    }

    private var keyboardRequirementRow: some View {
        OnboardingStepRow(
            isCompleted: isKeyboardRequirementAvailable && keyboardAccessProbe.hasConfirmedKeyboardAccess,
            stepNumber: 3,
            title: "Enable Keyboard",
            description: keyboardStepDescription,
            buttonTitle: keyboardStepButton?.title,
            isButtonEnabled: keyboardStepButton?.isEnabled ?? true,
            action: keyboardStepButton?.action
        )
    }

    private var modelStepButton: OnboardingStepButton? {
        switch modelManager.installState {
        case .notInstalled:
            return OnboardingStepButton(
                title: downloadNetworkMonitor.isOnCellular ? "Download Now" : "Download",
                isEnabled: true,
                action: { modelManager.downloadModel() }
            )
        case .failed:
            return OnboardingStepButton(
                title: "Repair",
                isEnabled: true,
                action: { modelManager.repairModelIfNeeded() }
            )
        case .downloading, .installing, .ready:
            return nil
        }
    }

    private var modelStepDescription: String {
        switch modelManager.installState {
        case .notInstalled:
            return "OpenAI Whisper Base (~190 MB)"
        case .downloading(_, let phase), .installing(_, let phase):
            return phase.statusText
        case .ready:
            return "Model ready"
        case .failed:
            return "Model repair needed"
        }
    }

    private var microphoneStepButton: OnboardingStepButton? {
        switch microphonePermissionController.status {
        case .undetermined:
            return OnboardingStepButton(
                title: "Allow access",
                isEnabled: true,
                action: {
                    Task {
                        await microphonePermissionController.requestPermission()
                    }
                }
            )
        case .denied:
            return OnboardingStepButton(
                title: "Open Settings",
                isEnabled: true,
                action: { openAppSettings() }
            )
        case .granted:
            return nil
        }
    }

    private var keyboardStepDescription: String {
        guard isKeyboardRequirementAvailable else {
            return "Finish downloading the model and allow microphone access before continuing."
        }

        if keyboardAccessProbe.isKeyboardEnabledInSystemSettings {
            return "KeyVox Keyboard is enabled. Open Settings and turn on Allow Full Access to finish setup."
        }

        return "Enable KeyVox Keyboard and turn on Allow Full Access in Settings, then come back here."
    }

    private var keyboardStepButton: OnboardingStepButton? {
        if keyboardAccessProbe.hasConfirmedKeyboardAccess {
            return nil
        }

        guard isKeyboardRequirementAvailable else {
            return OnboardingStepButton(
                title: "Open Settings",
                isEnabled: false,
                action: {}
            )
        }

        if keyboardAccessProbe.isKeyboardEnabledInSystemSettings && keyboardAccessProbe.hasFullAccessConfirmedByKeyboard {
            return OnboardingStepButton(
                title: "Check again",
                isEnabled: true,
                action: { keyboardAccessProbe.refresh() }
            )
        }

        return OnboardingStepButton(
            title: "Open Settings",
            isEnabled: true,
            action: { openKeyboardSettings() }
        )
    }

    private func refreshState() {
        modelManager.refreshStatus()
        microphonePermissionController.refreshStatus()
        keyboardAccessProbe.refresh()
    }

    private func openKeyboardSettings() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let url = URL(string: "App-prefs:\(bundleIdentifier)") else {
            return
        }

        KeyVoxIPCBridge.clearKeyboardOnboardingPresentation()
        onboardingStore.recordPendingKeyboardTour()
        UIApplication.shared.open(url)
    }

    private func openAppSettings() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let url = URL(string: "App-prefs:\(bundleIdentifier)") else {
            return
        }

        UIApplication.shared.open(url)
    }

    private var shouldShowCellularModelWarning: Bool {
        downloadNetworkMonitor.isOnCellular && modelManager.installState == .notInstalled
    }

    private var formattedDownloadSize: String {
        Self.megabytesString(for: modelManager.requiredDownloadBytes)
    }

    private var isKeyboardRequirementAvailable: Bool {
        modelManager.installState == .ready && microphonePermissionController.status == .granted
    }

    private var modelDownloadProgress: Double? {
        switch modelManager.installState {
        case .downloading(let progress, _),
             .installing(let progress, _):
            return progress
        default:
            return nil
        }
    }

    private static func megabytesString(for byteCount: Int64) -> String {
        let megabytes = Double(byteCount) / 1_000_000
        return String(format: "%.1f MB", megabytes)
    }

}
