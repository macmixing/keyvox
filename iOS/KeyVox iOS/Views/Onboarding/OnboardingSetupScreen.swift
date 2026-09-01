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
    @EnvironmentObject private var settingsStore: AppSettingsStore
    @StateObject private var downloadNetworkMonitor: OnboardingDownloadNetworkMonitor
    @StateObject private var microphonePermissionController: OnboardingMicrophonePermissionController
    @State private var previousWarningToken: String?
    @State private var previousModelStepCompletion: Bool?
    @State private var displaysMicrophoneStepCompletion = false
    @State private var hasPendingMicrophoneStepCompletion = false
    @State private var pendingDownloadConfirmation: PendingDownloadConfirmation?
    private let onboardingModelID: DictationModelID = .whisperBase

    @MainActor
    init(
        downloadNetworkMonitor: OnboardingDownloadNetworkMonitor? = nil,
        microphonePermissionController: OnboardingMicrophonePermissionController? = nil
    ) {
        let resolvedDownloadNetworkMonitor = downloadNetworkMonitor ?? OnboardingDownloadNetworkMonitor()
        let resolvedMicrophonePermissionController = microphonePermissionController ?? OnboardingMicrophonePermissionController()

        _downloadNetworkMonitor = StateObject(wrappedValue: resolvedDownloadNetworkMonitor)
        _microphonePermissionController = StateObject(wrappedValue: resolvedMicrophonePermissionController)
    }

    var body: some View {
        NavigationStack {
            AppScrollScreen {
                VStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Just a few steps...")
                            .font(.appFont(34))
                            .foregroundStyle(.white)

                        Text("After this, you may never type again.")
                            .font(.appFont(14, variant: .light))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)

                    modelRequirementRow
                    microphoneRequirementRow
                    keyboardRequirementRow
                }
                .padding(.bottom, 24)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        appHaptics.light()
                        onboardingStore.returnToLanguageSelection()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .task {
            refreshState()
            selectOnboardingProviderIfReady()
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
            selectOnboardingProviderIfReady()
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
        .downloadConfirmation($pendingDownloadConfirmation, onConfirm: performDownloadConfirmation)
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
                        InlineWarningRow(
                            text: InlineWarningRow.Copy.cellularDownloadRecommended,
                            fontSize: 12,
                            iconSize: 11
                        )
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
            isCompleted: false,
            stepNumber: 3,
            title: "Keyboard & Shortcut",
            description: "Set up the KeyVox keyboard and shortcut to access dictation anywhere.",
            buttonTitle: "Continue",
            isButtonEnabled: isKeyboardRequirementAvailable,
            action: beginDictationShortcutSetup
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
                    pendingDownloadConfirmation = .dictationModel(onboardingModelID)
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
                title: "Continue",
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

    private func refreshState() {
        modelManager.refreshStatus()
        microphonePermissionController.refreshStatus()
    }

    private func performDownloadConfirmation(_ confirmation: PendingDownloadConfirmation) {
        switch confirmation {
        case .dictationModel(let modelID):
            modelManager.downloadModel(withID: modelID)
        case .keyVoxVibesAI, .sharedTTSModel, .ttsVoice, .ttsVoiceWithSharedModel:
            // Onboarding only confirms dictation model downloads; other download confirmations are owned by their feature surfaces.
            break
        }
    }

    private func openAppSettings() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier,
              let url = URL(string: "App-prefs:\(bundleIdentifier)") else {
            return
        }

        UIApplication.shared.open(url)
    }

    private var shouldShowCellularModelWarning: Bool {
        InlineWarningRules.showsOnboardingCellularModelWarning(
            isOnCellular: downloadNetworkMonitor.isOnCellular,
            modelState: onboardingModelState
        )
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

    private func selectOnboardingProviderIfReady() {
        guard onboardingModelState == .ready else { return }
        settingsStore.activeDictationProvider = .whisper
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

    private func beginDictationShortcutSetup() {
        guard isKeyboardRequirementAvailable else { return }
        appHaptics.medium()
        onboardingStore.beginDictationShortcutSetup()
    }
}
