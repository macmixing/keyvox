import SwiftUI

extension HomeTabView {
    @ViewBuilder
    var speakClipboardSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.2))
                            .frame(width: 32, height: 32)

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speak Copied Text")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(settingsStore.ttsVoice.displayName)
                            .font(.appFont(15, variant: .light))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    AppActionButton(
                        title: ttsButtonTitle,
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        isEnabled: isTTSButtonEnabled,
                        action: handlePrimaryTTSAction
                    )
                }

                Text(ttsStatusText)
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))

                if showsTTSPreparationSlot {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: ttsManager.playbackPreparationProgress)
                            .progressViewStyle(KeyVoxProgressStyle())
                            .frame(height: 12)

                        Text(ttsPreparationProgressLabel)
                            .font(.appFont(13, variant: .medium))
                            .foregroundStyle(ttsPreparationProgressAccent)
                    }
                    .opacity(isTTSPreparationVisible ? 1 : 0)
                    .allowsHitTesting(isTTSPreparationVisible)
                    .accessibilityHidden(!isTTSPreparationVisible)
                }

                if let ttsErrorText {
                    Text(ttsErrorText)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                }
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: ttsManager.playbackPreparationProgress)
        .animation(.easeOut(duration: 0.14), value: isTTSPreparationVisible)
        .animation(.easeInOut(duration: 0.52), value: showsTTSPreparationSlot)
        .onAppear {
            syncTTSPreparationPresentation()
        }
        .onChange(of: showsTTSPreparationProgress, initial: true) { _, _ in
            updateTTSPreparationPresentation()
        }
        .onDisappear {
            ttsPreparationCollapseTask?.cancel()
        }
    }

    var ttsButtonTitle: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            return "Install"
        }

        switch pocketTTSModelManager.installState(for: settingsStore.ttsVoice) {
        case .notInstalled:
            return "Install"
        case .downloading, .installing:
            return "Installing"
        case .failed:
            return "Repair"
        case .ready:
            return ttsManager.isActive ? "Stop" : "Speak"
        }
    }

    var ttsStatusText: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            switch pocketTTSModelManager.sharedModelInstallState {
            case .notInstalled:
                return "Install PocketTTS CoreML to read copied text aloud."
            case .downloading:
                return "Downloading PocketTTS CoreML..."
            case .installing:
                return "Installing PocketTTS CoreML..."
            case .failed:
                return "PocketTTS CoreML install failed."
            case .ready:
                break
            }
        }

        switch pocketTTSModelManager.installState(for: settingsStore.ttsVoice) {
        case .notInstalled:
            return "Install the \(settingsStore.ttsVoice.displayName) voice to read copied text aloud."
        case .downloading:
            return "Downloading the \(settingsStore.ttsVoice.displayName) voice..."
        case .installing:
            return "Installing the \(settingsStore.ttsVoice.displayName) voice..."
        case .failed:
            return "\(settingsStore.ttsVoice.displayName) voice install failed."
        case .ready:
            break
        }

        switch ttsManager.state {
        case .idle:
            return "Read copied text aloud using your selected voice."
        case .preparing:
            return "Preparing playback..."
        case .generating:
            return "Rendering startup audio..."
        case .playing:
            return "Speaking copied text."
        case .finished:
            return "Finished speaking."
        case .error:
            return "Playback failed."
        }
    }

    var ttsErrorText: String? {
        ttsManager.lastErrorMessage
    }

    var showsTTSPreparationProgress: Bool {
        switch ttsManager.state {
        case .preparing, .generating:
            return true
        case .idle, .playing, .finished, .error:
            return false
        }
    }

    var ttsPreparationProgressLabel: String {
        "\(Int(ttsManager.playbackPreparationProgress * 100))%"
    }

    var ttsPreparationProgressAccent: Color {
        ttsManager.playbackPreparationProgress >= 1 ? .yellow : AppTheme.accent
    }

    func syncTTSPreparationPresentation() {
        showsTTSPreparationSlot = showsTTSPreparationProgress
        isTTSPreparationVisible = showsTTSPreparationProgress
    }

    func updateTTSPreparationPresentation() {
        ttsPreparationCollapseTask?.cancel()

        if showsTTSPreparationProgress {
            if showsTTSPreparationSlot == false {
                showsTTSPreparationSlot = true
            }

            withAnimation(.easeOut(duration: 0.14)) {
                isTTSPreparationVisible = true
            }
            return
        }

        guard showsTTSPreparationSlot else { return }

        withAnimation(.easeOut(duration: 0.14)) {
            isTTSPreparationVisible = false
        }

        ttsPreparationCollapseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 240_000_000)
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: 0.52)) {
                showsTTSPreparationSlot = false
            }
        }
    }

    var isTTSButtonEnabled: Bool {
        switch pocketTTSModelManager.sharedModelInstallState {
        case .downloading, .installing:
            return false
        case .notInstalled, .failed, .ready:
            break
        }

        switch pocketTTSModelManager.installState(for: settingsStore.ttsVoice) {
        case .downloading, .installing:
            return false
        case .notInstalled, .failed, .ready:
            return true
        }
    }

    func handlePrimaryTTSAction() {
        if pocketTTSModelManager.isSharedModelReady() == false {
            switch pocketTTSModelManager.sharedModelInstallState {
            case .notInstalled:
                pocketTTSModelManager.downloadSharedModel()
            case .failed:
                pocketTTSModelManager.repairSharedModelIfNeeded()
            case .downloading, .installing, .ready:
                break
            }
            return
        }

        switch pocketTTSModelManager.installState(for: settingsStore.ttsVoice) {
        case .notInstalled:
            pocketTTSModelManager.downloadVoice(settingsStore.ttsVoice)
        case .failed:
            pocketTTSModelManager.repairVoiceIfNeeded(settingsStore.ttsVoice)
        case .downloading, .installing:
            break
        case .ready:
            audioModeCoordinator.handleSpeakClipboardFromApp()
        }
    }
}
