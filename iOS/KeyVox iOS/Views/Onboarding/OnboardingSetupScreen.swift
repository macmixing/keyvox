import SwiftUI
import UIKit

private struct OnboardingStepButton {
    let title: String
    let isEnabled: Bool
    let action: () -> Void
}

struct OnboardingSetupScreen: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.appHaptics) private var appHaptics
    @EnvironmentObject private var modelManager: ModelManager
    @EnvironmentObject private var onboardingStore: OnboardingStore
    @StateObject private var downloadNetworkMonitor: OnboardingDownloadNetworkMonitor
    @StateObject private var microphonePermissionController: OnboardingMicrophonePermissionController
    @StateObject private var keyboardAccessProbe: OnboardingKeyboardAccessProbe
    @State private var previousWarningToken: String?
    @State private var previousModelStepCompletion: Bool?
    @State private var previousKeyboardStepCompletion: Bool?
    @State private var displaysMicrophoneStepCompletion = false
    @State private var hasPendingMicrophoneStepCompletion = false
    private let onboardingModelID: DictationModelID = .whisperBase

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
            VStack(alignment: .center, spacing: 16) {
                Text("Set up KeyVox")
                    .font(.appFont(34))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

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

            if hasPendingMicrophoneStepCompletion,
               microphonePermissionController.status == .granted {
                completeMicrophoneStep()
            }
        }
        .onAppear {
            previousWarningToken = currentWarningToken
            previousModelStepCompletion = isModelStepCompleted
            previousKeyboardStepCompletion = isKeyboardStepCompleted
            displaysMicrophoneStepCompletion = microphonePermissionController.status == .granted
        }
        .onChange(of: currentWarningToken, initial: false) { _, newToken in
            guard let newToken, newToken != previousWarningToken else {
                previousWarningToken = newToken
                return
            }

            appHaptics.warning()
            previousWarningToken = newToken
        }
        .onChange(of: isModelStepCompleted, initial: false) { _, newValue in
            emitStepCompletionHaptic(previousCompletion: &previousModelStepCompletion, newValue: newValue)
        }
        .onChange(of: isKeyboardStepCompleted, initial: false) { _, newValue in
            emitStepCompletionHaptic(previousCompletion: &previousKeyboardStepCompletion, newValue: newValue)
        }
        .onChange(of: microphonePermissionController.status, initial: false) { oldValue, newValue in
            if newValue != .granted {
                displaysMicrophoneStepCompletion = false
                hasPendingMicrophoneStepCompletion = false
                return
            }

            guard oldValue != .granted else { return }

            if scenePhase == .active {
                completeMicrophoneStep()
            } else {
                hasPendingMicrophoneStepCompletion = true
            }
        }
    }

    @ViewBuilder
    private var modelRequirementRow: some View {
        OnboardingStepRow(
            isCompleted: isModelStepCompleted,
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

                    if shouldShowOfflineModelError {
                        Text("An internet connection is required for model download.")
                            .font(.appFont(12))
                            .foregroundStyle(.red)
                    } else if let storageError = preflightModelStorageError {
                        Text(storageError)
                            .font(.appFont(12))
                            .foregroundStyle(.red)
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
            isCompleted: displaysMicrophoneStepCompletion,
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
            isCompleted: isKeyboardStepCompleted,
            stepNumber: 3,
            title: "Enable Keyboard",
            description: keyboardStepDescription,
            buttonTitle: keyboardStepButton?.title,
            isButtonEnabled: keyboardStepButton?.isEnabled ?? true,
            action: keyboardStepButton?.action
        )
    }

    private var modelStepButton: OnboardingStepButton? {
        switch onboardingModelState {
        case .notInstalled:
            return OnboardingStepButton(
                title: downloadNetworkMonitor.isOnCellular ? "Download Now" : "Download",
                isEnabled: downloadNetworkMonitor.isOnline && preflightModelStorageError == nil,
                action: {
                    appHaptics.light()
                    modelManager.downloadModel(withID: onboardingModelID)
                }
            )
        case .failed:
            return OnboardingStepButton(
                title: "Repair",
                isEnabled: true,
                action: {
                    appHaptics.light()
                    modelManager.repairModelIfNeeded(for: onboardingModelID)
                }
            )
        case .downloading, .installing, .ready:
            return nil
        }
    }

    private var modelStepDescription: String {
        switch onboardingModelState {
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
                    appHaptics.light()
                    Task {
                        await microphonePermissionController.requestPermission()
                    }
                }
            )
        case .denied:
            return OnboardingStepButton(
                title: "Open Settings",
                isEnabled: true,
                action: {
                    appHaptics.light()
                    openAppSettings()
                }
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
                action: {
                    appHaptics.light()
                    keyboardAccessProbe.refresh()
                }
            )
        }

        return OnboardingStepButton(
            title: "Open Settings",
            isEnabled: true,
            action: {
                appHaptics.light()
                openKeyboardSettings()
            }
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
        downloadNetworkMonitor.isOnCellular && onboardingModelState == .notInstalled
    }

    private var shouldShowOfflineModelError: Bool {
        !downloadNetworkMonitor.isOnline && onboardingModelState == .notInstalled
    }

    private var preflightModelStorageError: String? {
        guard onboardingModelState == .notInstalled else {
            return nil
        }

        return modelManager.preflightDiskSpaceErrorMessage(for: onboardingModelID)
    }

    private var isKeyboardRequirementAvailable: Bool {
        onboardingModelState == .ready && microphonePermissionController.status == .granted
    }

    private var isModelStepCompleted: Bool {
        onboardingModelState == .ready
    }

    private var isKeyboardStepCompleted: Bool {
        isKeyboardRequirementAvailable && keyboardAccessProbe.hasConfirmedKeyboardAccess
    }

    private var currentWarningToken: String? {
        if case .failed(let message) = onboardingModelState, shouldShowOfflineModelError == false {
            return "model.error.\(message)"
        }

        if case .failed = onboardingModelState {
            return "model.failed"
        }

        if let storageError = preflightModelStorageError, shouldShowOfflineModelError == false {
            return "model.storage.\(storageError)"
        }

        if microphonePermissionController.status == .denied {
            return "microphone.denied"
        }

        return nil
    }

    private var modelDownloadProgress: Double? {
        switch onboardingModelState {
        case .downloading(let progress, _),
             .installing(let progress, _):
            return progress
        default:
            return nil
        }
    }

    private var onboardingModelState: ModelInstallState {
        modelManager.state(for: onboardingModelID)
    }

    private func emitStepCompletionHaptic(previousCompletion: inout Bool?, newValue: Bool) {
        if let event = OnboardingStepCompletionHapticsDecision.event(
            previousIsCompleted: previousCompletion,
            currentIsCompleted: newValue
        ) {
            appHaptics.emit(event)
        }

        previousCompletion = newValue
    }

    private func completeMicrophoneStep() {
        appHaptics.success()
        displaysMicrophoneStepCompletion = true
        hasPendingMicrophoneStepCompletion = false
    }

}
