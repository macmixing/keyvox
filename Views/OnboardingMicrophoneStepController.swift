import Foundation
import AVFoundation
import Combine

@MainActor
final class OnboardingMicrophoneStepController: ObservableObject {
    @Published private(set) var micAuthorized: Bool = false
    @Published private(set) var showMicSelectionPrompt: Bool = false
    @Published private(set) var micSelectionConfirmed: Bool = false
    @Published private(set) var pendingMicAuthorizationCompletion: Bool = false
    @Published var onboardingMicSelectionUID: String = ""

    private let audioDeviceManager: AudioDeviceManager
    private let appSettings: AppSettingsStore

    init(
        audioDeviceManager: AudioDeviceManager = .shared,
        appSettings: AppSettingsStore = .shared
    ) {
        self.audioDeviceManager = audioDeviceManager
        self.appSettings = appSettings
    }

    var microphoneStepButtonTitle: String {
        if isMicStepCompleted {
            return "Authorized"
        }
        if pendingMicAuthorizationCompletion {
            return "Choose Mic"
        }
        return "Grant Access"
    }

    var isMicStepCompleted: Bool {
        micAuthorized && !pendingMicAuthorizationCompletion
    }

    func handleOnboardingAppear() {
        micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        micSelectionConfirmed = micAuthorized && !appSettings.selectedMicrophoneUID.isEmpty

        guard micAuthorized else { return }
        evaluateMicrophoneSelectionRequirement()
    }

    func requestMicAccess() {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        switch currentStatus {
        case .authorized:
            micAuthorized = true
            evaluateMicrophoneSelectionRequirement()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    self.micAuthorized = granted
                    if granted {
                        self.evaluateMicrophoneSelectionRequirement()
                    } else {
                        self.micSelectionConfirmed = false
                        self.pendingMicAuthorizationCompletion = false
                        self.showMicSelectionPrompt = false
                    }
                }
            }
        case .denied, .restricted:
            micAuthorized = false
            micSelectionConfirmed = false
            pendingMicAuthorizationCompletion = false
            showMicSelectionPrompt = false
        @unknown default:
            micAuthorized = false
            micSelectionConfirmed = false
            pendingMicAuthorizationCompletion = false
            showMicSelectionPrompt = false
        }
    }

    func handleMicrophoneOptionsChanged() {
        guard showMicSelectionPrompt else { return }
        syncOnboardingSelectionWithAvailableMicrophones()
    }

    func confirmOnboardingMicrophoneSelection() {
        guard !onboardingMicSelectionUID.isEmpty else { return }
        appSettings.selectedMicrophoneUID = onboardingMicSelectionUID
        micAuthorized = true
        micSelectionConfirmed = true
        pendingMicAuthorizationCompletion = false
        showMicSelectionPrompt = false
    }

    private var isMicPickerDebugOverrideEnabled: Bool {
        let value = ProcessInfo.processInfo.environment["KEYVOX_FORCE_MIC_PICKER"]?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        return value == "1" || value == "true" || value == "yes"
    }

    private var requiresMicSelectionPrompt: Bool {
        micAuthorized && (isMicPickerDebugOverrideEnabled || !audioDeviceManager.hasRecommendedBuiltInMicrophone)
    }

    private func evaluateMicrophoneSelectionRequirement() {
        audioDeviceManager.refreshAvailableMicrophones()

        let requiresPicker = requiresMicSelectionPrompt
        if requiresPicker {
            if micSelectionConfirmed {
                pendingMicAuthorizationCompletion = false
                showMicSelectionPrompt = false
                return
            }

            pendingMicAuthorizationCompletion = true
            showMicSelectionPrompt = true
            syncOnboardingSelectionWithAvailableMicrophones()
            return
        }

        pendingMicAuthorizationCompletion = false
        showMicSelectionPrompt = false
    }

    private func syncOnboardingSelectionWithAvailableMicrophones() {
        let microphones = audioDeviceManager.pickerMicrophones
        guard !microphones.isEmpty else {
            onboardingMicSelectionUID = ""
            return
        }

        if microphones.contains(where: { $0.id == onboardingMicSelectionUID }) {
            return
        }

        if !appSettings.selectedMicrophoneUID.isEmpty,
           microphones.contains(where: { $0.id == appSettings.selectedMicrophoneUID }) {
            onboardingMicSelectionUID = appSettings.selectedMicrophoneUID
            return
        }

        onboardingMicSelectionUID = microphones[0].id
    }
}
