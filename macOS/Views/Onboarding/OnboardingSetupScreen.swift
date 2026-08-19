import AppKit
import AVFoundation
import SwiftUI

struct OnboardingSetupScreen: View {
    private struct HeightPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = OnboardingView.preferredWindowSize.height

        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value = max(value, nextValue())
        }
    }

    @ObservedObject private var downloader = ModelDownloader.shared
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    @StateObject private var microphoneStepController = OnboardingMicrophoneStepController()
    @State private var accessibilityAuthorized = false
    @State private var accessibilityPollTimer: Timer?

    private let accessibilityPollInterval: TimeInterval = 0.3

    let onBack: () -> Void
    let onComplete: () -> Void
    let openSettings: () -> Void
    let beginMicrophoneAuthorization: () -> Void
    let beginAccessibilityAuthorization: () -> Void
    let endAccessibilityAuthorization: () -> Void
    let onPreferredHeightChange: (CGFloat) -> Void

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    LogoBarView(size: 75)

                    VStack(spacing: 4) {
                        Text("Just a few steps...")
                            .font(.appFont(32))
                            .foregroundColor(.white)

                        Text("After this, you may never type again.")
                            .font(.appFont(14, variant: .light))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 50)

                VStack(spacing: 12) {
                    OnboardingStepRow(
                        isCompleted: downloader.isModelDownloaded,
                        stepNumber: 1,
                        title: "AI Model Setup",
                        description: "OpenAI Whisper Base (~190 MB)",
                        buttonTitle: downloader.isModelDownloaded ? "Ready" : (downloader.isDownloading ? "Downloading..." : "Download"),
                        action: setupModel
                    ) {
                        if downloader.isDownloading {
                            LabeledProgressBar(progress: downloader.progress, statusText: "Downloading AI model.")
                                .padding(.top, 8)
                        } else if let error = downloader.errorMessage {
                            Text(error)
                                .font(.appFont(10, variant: .light))
                                .foregroundColor(.red)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 8)
                        }
                    }

                    OnboardingStepRow(
                        isCompleted: microphoneStepController.isMicStepCompleted,
                        stepNumber: 2,
                        title: "Microphone Access",
                        description: "KeyVox needs to hear you to transcribe.",
                        buttonTitle: microphoneStepController.isMicStepCompleted ? "Ready" : "Continue",
                        action: requestMicrophoneAccess
                    )

                    OnboardingStepRow(
                        isCompleted: accessibilityAuthorized,
                        stepNumber: 3,
                        title: "Accessibility Access",
                        description: "Required to paste text into other apps.",
                        buttonTitle: accessibilityAuthorized ? "Ready" : "Open Settings",
                        action: requestAccessibilityAccess
                    )
                }
                .padding(.horizontal, 30)

                VStack(spacing: 12) {
                    AppActionButton(
                        title: "Start Using KeyVox",
                        style: .primary,
                        minWidth: 240,
                        fontSize: 18,
                        isEnabled: allStepsCompleted
                    ) {
                        onComplete()
                    }

                    Text("Complete all steps to proceed")
                        .font(.appFont(11, variant: .light))
                        .foregroundColor(.secondary.opacity(0.5))
                        .opacity(allStepsCompleted ? 0 : 1)
                }
            }
            .padding(.bottom, 32)
            .disabled(microphoneStepController.showMicSelectionPrompt)

            if microphoneStepController.showMicSelectionPrompt {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                OnboardingMicrophonePickerView(
                    selectedMicrophoneUID: $microphoneStepController.onboardingMicSelectionUID,
                    microphones: audioDeviceManager.pickerMicrophones,
                    onConfirm: microphoneStepController.confirmOnboardingMicrophoneSelection
                )
                .frame(width: 310)
                .padding(.horizontal, 20)
            }

            VStack {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(MacAppTheme.cardFill))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Back")
                    .disabled(microphoneStepController.showMicSelectionPrompt)

                    Spacer()
                }

                Spacer()
            }
            .padding(.leading, 25)
            .padding(.trailing, 30)
            .padding(.top, 36)
            .padding(.bottom, 20)
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(
            GeometryReader { geometry in
                Color.clear.preference(
                    key: HeightPreferenceKey.self,
                    value: geometry.size.height
                )
            }
        )
        .frame(width: OnboardingView.preferredWindowSize.width)
        .frame(minHeight: OnboardingView.preferredWindowSize.height)
        .background(MacAppTheme.screenBackground)
        .onPreferenceChange(HeightPreferenceKey.self) { height in
            onPreferredHeightChange(max(OnboardingView.preferredWindowSize.height, height))
        }
        .onAppear {
            checkCurrentStatus()
            microphoneStepController.handleOnboardingAppear()
        }
        .onDisappear {
            accessibilityPollTimer?.invalidate()
            accessibilityPollTimer = nil
        }
        .onChange(of: audioDeviceManager.pickerMicrophones.map(\.id)) { _ in
            microphoneStepController.handleMicrophoneOptionsChanged()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            microphoneStepController.handleAppDidBecomeActive()
        }
        .animation(.spring(), value: allStepsCompleted)
    }

    private var allStepsCompleted: Bool {
        microphoneStepController.isMicStepCompleted && accessibilityAuthorized && downloader.isModelDownloaded
    }

    private func checkCurrentStatus() {
        accessibilityAuthorized = AXIsProcessTrusted()
    }

    @MainActor
    private func requestMicrophoneAccess() {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        if status == .denied || status == .restricted {
            beginMicrophoneAuthorization()
        }
        microphoneStepController.requestMicAccess()
    }

    private func requestAccessibilityAccess() {
        beginAccessibilityAuthorization()

        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)

        if AXIsProcessTrusted() {
            accessibilityAuthorized = true
            accessibilityPollTimer?.invalidate()
            accessibilityPollTimer = nil
            endAccessibilityAuthorization()
            return
        }

        accessibilityPollTimer?.invalidate()

        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: accessibilityPollInterval, repeats: true) { timer in
            if AXIsProcessTrusted() {
                DispatchQueue.main.async {
                    self.accessibilityAuthorized = true
                    self.endAccessibilityAuthorization()
                }
                timer.invalidate()
                accessibilityPollTimer = nil
            }
        }
    }

    private func setupModel() {
        downloader.downloadBaseModel()
    }
}

private struct OnboardingStepRow<Content: View>: View {
    let isCompleted: Bool
    let stepNumber: Int
    let title: String
    let description: String
    let buttonTitle: String
    let action: @MainActor () -> Void
    let extraContent: Content

    init(
        isCompleted: Bool,
        stepNumber: Int,
        title: String,
        description: String,
        buttonTitle: String,
        action: @escaping @MainActor () -> Void,
        @ViewBuilder extraContent: () -> Content = { EmptyView() }
    ) {
        self.isCompleted = isCompleted
        self.stepNumber = stepNumber
        self.title = title
        self.description = description
        self.buttonTitle = buttonTitle
        self.action = action
        self.extraContent = extraContent()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : MacAppTheme.accent.opacity(0.2))
                        .frame(width: 32, height: 32)

                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(stepNumber)")
                            .font(.appFont(16))
                            .foregroundColor(.white)
                    }
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.appFont(16))
                        .foregroundColor(.white)

                    Text(description)
                        .font(.appFont(12, variant: .light))
                        .foregroundColor(.secondary)
                }

                Spacer()

                AppActionButton(
                    title: buttonTitle,
                    style: isCompleted ? .secondary : .primary,
                    minWidth: 104,
                    isEnabled: !isActionDisabled,
                    action: action
                )
            }

            extraContent
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompleted ? Color.green.opacity(0.05) : MacAppTheme.tipFill)
        )
    }

    private var isActionDisabled: Bool {
        isCompleted || (stepNumber == 1 && buttonTitle == "Downloading...")
    }
}
