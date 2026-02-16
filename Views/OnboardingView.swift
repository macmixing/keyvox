import SwiftUI

struct OnboardingView: View {
    @ObservedObject var downloader = ModelDownloader.shared
    @ObservedObject private var audioDeviceManager = AudioDeviceManager.shared
    @StateObject private var microphoneStepController = OnboardingMicrophoneStepController()
    @State private var accessibilityAuthorized: Bool = false
    @State private var accessibilityPollTimer: Timer?
    
    var onComplete: () -> Void
    var openSettings: () -> Void
    var beginAccessibilityAuthorization: () -> Void = {}
    var endAccessibilityAuthorization: () -> Void = {}
    
    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    KeyVoxLogo(size: 80)

                    VStack(spacing: 4) {
                        Text("Welcome to KeyVox")
                            .font(.custom("Kanit Medium", size: 32))
                            .foregroundColor(.indigo)

                        Text("Let's get you set up in three quick steps.")
                            .font(.custom("Kanit Medium", size: 14))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.top, 50)

                // Steps
                VStack(spacing: 12) {
                    OnboardingStepRow(
                        isCompleted: microphoneStepController.isMicStepCompleted,
                        stepNumber: 1,
                        title: "Microphone Access",
                        description: "KeyVox needs to hear you to transcribe.",
                        buttonTitle: microphoneStepController.microphoneStepButtonTitle,
                        action: microphoneStepController.requestMicAccess
                    )

                    OnboardingStepRow(
                        isCompleted: accessibilityAuthorized,
                        stepNumber: 2,
                        title: "Accessibility Access",
                        description: "Required to paste text into other apps.",
                        buttonTitle: accessibilityAuthorized ? "Authorized" : "Grant Access",
                        action: requestAccessibilityAccess
                    )

                    OnboardingStepRow(
                        isCompleted: downloader.isModelDownloaded,
                        stepNumber: 3,
                        title: "AI Model Setup",
                        description: "Download the OpenAI Whisper engine.",
                        buttonTitle: downloader.isModelDownloaded ? "Ready" : (downloader.isDownloading ? "Downloading..." : "Download Now"),
                        action: setupModel
                    ) {
                        if downloader.isDownloading {
                            ModelDownloadProgress(progress: downloader.progress)
                                .padding(.top, 8)
                        }
                    }
                }
                .padding(.horizontal, 30)

                // Footer - Persistent Button
                VStack(spacing: 12) {
                    Button(action: onComplete) {
                        Text("Start Using KeyVox")
                            .font(.custom("Kanit Medium", size: 16))
                            .foregroundColor(allStepsCompleted ? .black : .white.opacity(0.3))
                            .padding(.horizontal, 40)
                            .padding(.vertical, 12)
                            .frame(minWidth: 240)
                            .background(allStepsCompleted ? Color.yellow : Color.white.opacity(0.05))
                            .cornerRadius(25)
                            .shadow(color: allStepsCompleted ? .yellow.opacity(0.3) : .clear, radius: 10)
                    }
                    .buttonStyle(.plain)
                    .disabled(!allStepsCompleted)

                    Text("Complete all steps to proceed")
                        .font(.custom("Kanit Medium", size: 11))
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
        }
        .frame(width: 500, height: 520)
        .background(
            Color.indigo.opacity(0.15)
                .background(Color(white: 0.01))
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
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
        .animation(.spring(), value: allStepsCompleted)
    }

    private var allStepsCompleted: Bool {
        microphoneStepController.isMicStepCompleted && accessibilityAuthorized && downloader.isModelDownloaded
    }
    
    private func checkCurrentStatus() {
        accessibilityAuthorized = AXIsProcessTrusted()
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

        // Prevent stacking multiple timers
        accessibilityPollTimer?.invalidate()

        accessibilityPollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
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

struct OnboardingStepRow<Content: View>: View {
    let isCompleted: Bool
    let stepNumber: Int
    let title: String
    let description: String
    let buttonTitle: String
    let action: () -> Void
    let extraContent: Content
    
    init(
        isCompleted: Bool,
        stepNumber: Int,
        title: String,
        description: String,
        buttonTitle: String,
        action: @escaping () -> Void,
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
                // Step Number Circle
                ZStack {
                    Circle()
                        .fill(isCompleted ? Color.green : Color.indigo.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    if isCompleted {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text("\(stepNumber)")
                            .font(.custom("Kanit Medium", size: 16))
                            .foregroundColor(.white)
                    }
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.custom("Kanit Medium", size: 16))
                        .foregroundColor(.white)
                    
                    Text(description)
                        .font(.custom("Kanit Medium", size: 12))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: action) {
                    Text(buttonTitle)
                        .font(.custom("Kanit Medium", size: 12))
                        .foregroundColor(isCompleted ? .green : .white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isCompleted ? Color.green : Color.white.opacity(0.3), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(isCompleted || (title == "AI Model Setup" && buttonTitle == "Downloading..."))
            }
            
            extraContent
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isCompleted ? Color.green.opacity(0.05) : Color.white.opacity(0.03))
        )
    }
}
