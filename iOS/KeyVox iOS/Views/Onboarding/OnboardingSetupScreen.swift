import SwiftUI
import UIKit

struct OnboardingSetupScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var modelManager: iOSModelManager
    @EnvironmentObject private var onboardingStore: iOSOnboardingStore
    @StateObject private var downloadNetworkMonitor: iOSOnboardingDownloadNetworkMonitor
    @StateObject private var microphonePermissionController: iOSOnboardingMicrophonePermissionController
    @StateObject private var keyboardAccessProbe: iOSOnboardingKeyboardAccessProbe

    @MainActor
    init(
        downloadNetworkMonitor: iOSOnboardingDownloadNetworkMonitor? = nil,
        microphonePermissionController: iOSOnboardingMicrophonePermissionController? = nil,
        keyboardAccessProbe: iOSOnboardingKeyboardAccessProbe? = nil
    ) {
        let resolvedDownloadNetworkMonitor = downloadNetworkMonitor ?? iOSOnboardingDownloadNetworkMonitor()
        let resolvedMicrophonePermissionController = microphonePermissionController ?? iOSOnboardingMicrophonePermissionController()
        let resolvedKeyboardAccessProbe = keyboardAccessProbe ?? iOSOnboardingKeyboardAccessProbe()

        _downloadNetworkMonitor = StateObject(wrappedValue: resolvedDownloadNetworkMonitor)
        _microphonePermissionController = StateObject(wrappedValue: resolvedMicrophonePermissionController)
        _keyboardAccessProbe = StateObject(wrappedValue: resolvedKeyboardAccessProbe)
    }

    var body: some View {
        iOSAppScrollScreen {
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
        VStack(alignment: .leading, spacing: 8) {
            OnboardingRequirementRow(
                title: "Download the model",
                detail: modelRequirementDetail,
                isComplete: modelManager.installState == .ready,
                actionTitle: modelRequirementActionTitle,
                action: modelRequirementAction
            )

            if shouldShowCellularModelWarning {
                Text("You’re on cellular. We recommend Wi-Fi for this download.")
                    .font(.appFont(12))
                    .foregroundStyle(.yellow)
                    .padding(.horizontal, 4)
            }
        }
    }

    private var microphoneRequirementRow: some View {
        OnboardingRequirementRow(
            title: "Allow microphone access",
            detail: microphoneRequirementDetail,
            isComplete: microphonePermissionController.status == .granted,
            detailColor: microphoneRequirementDetailColor,
            actionTitle: microphoneRequirementActionTitle,
            action: microphoneRequirementAction
        )
    }

    private var keyboardRequirementRow: some View {
        OnboardingRequirementRow(
            title: "Enable keyboard access",
            detail: keyboardRequirementDetail,
            isComplete: isKeyboardRequirementAvailable && keyboardAccessProbe.hasConfirmedKeyboardAccess,
            actionTitle: keyboardRequirementActionTitle,
            action: keyboardRequirementAction
        )
    }

    private var modelRequirementDetail: String {
        switch modelManager.installState {
        case .ready:
            return "Model downloaded and ready."
        case .downloading, .installing:
            return "\(modelManager.installState.statusText). You can keep finishing the other setup steps while this runs."
        case .notInstalled:
            return "Download size: \(formattedDownloadSize)"
        case .failed:
            return "\(modelManager.installState.statusText) Download size: \(formattedDownloadSize)"
        }
    }

    private var modelRequirementActionTitle: String? {
        switch modelManager.installState {
        case .notInstalled:
            return downloadNetworkMonitor.isOnCellular ? "Download now" : "Download"
        case .failed:
            return "Repair model"
        case .downloading, .installing, .ready:
            return nil
        }
    }

    private var modelRequirementAction: (() -> Void)? {
        switch modelManager.installState {
        case .notInstalled:
            return {
                modelManager.downloadModel()
            }
        case .failed:
            return {
                modelManager.repairModelIfNeeded()
            }
        case .downloading, .installing, .ready:
            return nil
        }
    }

    private var microphoneRequirementDetail: String {
        switch microphonePermissionController.status {
        case .undetermined:
            return "KeyVox needs microphone access to capture dictation."
        case .denied:
            return "Microphone access is off. Enable it in KeyVox Settings to continue onboarding."
        case .granted:
            return "Microphone access granted."
        }
    }

    private var microphoneRequirementDetailColor: Color {
        switch microphonePermissionController.status {
        case .denied:
            return .yellow
        case .undetermined, .granted:
            return .secondary
        }
    }

    private var microphoneRequirementActionTitle: String? {
        switch microphonePermissionController.status {
        case .undetermined:
            return "Allow access"
        case .denied:
            return "Open KeyVox Settings"
        case .granted:
            return nil
        }
    }

    private var microphoneRequirementAction: (() -> Void)? {
        switch microphonePermissionController.status {
        case .undetermined:
            return {
                Task {
                    await microphonePermissionController.requestPermission()
                }
            }
        case .denied:
            return {
                openAppSettings()
            }
        case .granted:
            return nil
        }
    }

    private var keyboardRequirementDetail: String {
        guard isKeyboardRequirementAvailable else {
            return "Finish downloading the model before setting up keyboard access."
        }

        if keyboardAccessProbe.hasConfirmedKeyboardAccess {
            return "Keyboard access confirmed."
        }

        if keyboardAccessProbe.isKeyboardEnabledInSystemSettings && keyboardAccessProbe.hasFullAccessConfirmedByKeyboard {
            return "Full Access is on. Open the KeyVox keyboard once more if setup still needs to finish."
        }

        if keyboardAccessProbe.isKeyboardEnabledInSystemSettings {
            return "KeyVox Keyboard is enabled. Open the KeyVox keyboard once with Full Access turned on to finish setup."
        }

        return "Enable KeyVox Keyboard and Allow Full Access in Settings, then open the KeyVox keyboard once."
    }

    private var keyboardRequirementActionTitle: String? {
        guard isKeyboardRequirementAvailable else {
            return nil
        }

        if keyboardAccessProbe.hasConfirmedKeyboardAccess {
            return nil
        }

        if keyboardAccessProbe.isKeyboardEnabledInSystemSettings && keyboardAccessProbe.hasFullAccessConfirmedByKeyboard {
            return "Check again"
        }

        return "Open KeyVox Settings"
    }

    private var keyboardRequirementAction: (() -> Void)? {
        guard isKeyboardRequirementAvailable else {
            return nil
        }

        guard !keyboardAccessProbe.hasConfirmedKeyboardAccess else {
            return nil
        }

        return {
            if keyboardAccessProbe.isKeyboardEnabledInSystemSettings && keyboardAccessProbe.hasFullAccessConfirmedByKeyboard {
                keyboardAccessProbe.refresh()
            } else {
                openKeyboardSettings()
            }
        }
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
        modelManager.installState == .ready
    }

    private static func megabytesString(for byteCount: Int64) -> String {
        let megabytes = Double(byteCount) / 1_000_000
        return String(format: "%.1f MB", megabytes)
    }

}
