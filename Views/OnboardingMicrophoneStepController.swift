import Foundation
import AVFoundation
import AppKit
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
        audioDeviceManager: AudioDeviceManager,
        appSettings: AppSettingsStore
    ) {
        self.audioDeviceManager = audioDeviceManager
        self.appSettings = appSettings
    }

    convenience init() {
        self.init(
            audioDeviceManager: .shared,
            appSettings: .shared
        )
    }

    var microphoneStepButtonTitle: String {
        if isMicStepCompleted {
            return "Authorized"
        }
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            return "Open Settings"
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
        updateMicAuthorizationState()

        guard micAuthorized else { return }
        evaluateMicrophoneSelectionRequirement()
    }

    func handleAppDidBecomeActive() {
        let wasAuthorized = micAuthorized
        updateMicAuthorizationState()

        guard micAuthorized else { return }
        if !wasAuthorized || showMicSelectionPrompt || pendingMicAuthorizationCompletion {
            evaluateMicrophoneSelectionRequirement()
        }
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
            openMicrophonePrivacySettings()
            updateMicAuthorizationState()
        @unknown default:
            openMicrophonePrivacySettings()
            updateMicAuthorizationState()
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

    private func updateMicAuthorizationState() {
        micAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        micSelectionConfirmed = micAuthorized && !appSettings.selectedMicrophoneUID.isEmpty
        if micAuthorized {
            return
        }
        pendingMicAuthorizationCompletion = false
        showMicSelectionPrompt = false
    }

    private func openMicrophonePrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}
