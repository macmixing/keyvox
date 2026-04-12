import SwiftUI

extension HomeTabView {
    private var ttsPreparationRevealDelaySeconds: Double {
        0.5
    }

    @ViewBuilder
    var ttsVoiceShortcutLabel: some View {
        if showsHomePlaybackVoiceShortcut == false {
            Text(effectiveTTSVoice.displayName)
                .font(.appFont(15, variant: .light))
                .foregroundStyle(.yellow)
        } else {
            PlaybackVoicePickerMenu(
                voices: installedPlaybackVoices,
                selection: installedVoiceSelection
            ) {
                Text(homePlaybackVoiceSummaryText)
                    .font(.appFont(15, variant: .light))
                    .foregroundStyle(.yellow)
            }
        }
    }

    var showsHomePlaybackVoiceShortcut: Bool {
        installedPlaybackVoices.count > 1
    }

    var installedPlaybackVoices: [AppSettingsStore.TTSVoice] {
        pocketTTSModelManager.installedVoices()
    }

    var installedVoiceSelection: Binding<AppSettingsStore.TTSVoice> {
        Binding(
            get: {
                if installedPlaybackVoices.contains(settingsStore.ttsVoice) {
                    return settingsStore.ttsVoice
                }

                return installedPlaybackVoices.first ?? settingsStore.ttsVoice
            },
            set: { newValue in
                guard installedPlaybackVoices.contains(newValue) else { return }
                guard settingsStore.ttsVoice != newValue else { return }

                appHaptics.light()
                settingsStore.ttsVoice = newValue
            }
        )
    }

    var homePlaybackVoiceSummaryText: String {
        if installedPlaybackVoices.contains(settingsStore.ttsVoice) {
            return settingsStore.ttsVoice.displayName
        }

        if let firstInstalledVoice = installedPlaybackVoices.first {
            return firstInstalledVoice.displayName
        }

        return effectiveTTSVoice.displayName
    }

    var ttsButtonTitle: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            return "Install"
        }

        switch pocketTTSModelManager.installState(for: effectiveTTSVoice) {
        case .notInstalled:
            return "Install"
        case .downloading, .installing:
            return "Installing"
        case .failed:
            return "Repair"
        case .ready:
            if ttsManager.isActive == false && ttsPurchaseController.canStartNewTTSSpeak == false {
                return "Unlock"
            }
            return ttsManager.isActive ? "Stop" : "Speak"
        }
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

    var ttsPreparationPercentageText: String? {
        showsTTSPreparationProgress ? ttsPreparationProgressLabel : nil
    }

    var activeTTSInstallState: PocketTTSInstallState? {
        if pocketTTSModelManager.isSharedModelReady() == false {
            switch pocketTTSModelManager.sharedModelInstallState {
            case .downloading, .installing:
                return pocketTTSModelManager.sharedModelInstallState
            case .notInstalled, .failed, .ready:
                break
            }
        }

        let voiceState = pocketTTSModelManager.installState(for: effectiveTTSVoice)
        switch voiceState {
        case .downloading, .installing:
            return voiceState
        case .notInstalled, .failed, .ready:
            return nil
        }
    }

    var showsTTSInstallProgressBar: Bool {
        activeTTSInstallState != nil
    }

    var isTTSPreparationPresentationActive: Bool {
        showsTTSPreparationProgress || showsTTSPreparationSlot || isTTSPreparationVisible
    }

    func syncTTSPreparationPresentation() {
        ttsPreparationRevealToken = UUID()
        showsTTSPreparationSlot = showsTTSPreparationProgress
        isTTSPreparationVisible = showsTTSPreparationProgress
    }

    func updateTTSPreparationPresentation() {
        ttsPreparationRevealToken = UUID()
        ttsPreparationCollapseTask?.cancel()

        if showsTTSPreparationProgress {
            if showsTTSPreparationSlot == false {
                showsTTSPreparationSlot = true
            }

            if isTTSPreparationVisible == false {
                let revealToken = UUID()
                ttsPreparationRevealToken = revealToken

                DispatchQueue.main.asyncAfter(deadline: .now() + ttsPreparationRevealDelaySeconds) {
                    guard ttsPreparationRevealToken == revealToken else { return }
                    guard showsTTSPreparationProgress else { return }

                    withAnimation(.easeOut(duration: 0.14)) {
                        isTTSPreparationVisible = true
                    }
                }
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

        switch pocketTTSModelManager.installState(for: effectiveTTSVoice) {
        case .downloading, .installing:
            return false
        case .notInstalled, .failed, .ready:
            return true
        }
    }

    var effectiveTTSVoice: AppSettingsStore.TTSVoice {
        if pocketTTSModelManager.isVoiceReady(settingsStore.ttsVoice) {
            return settingsStore.ttsVoice
        }

        return pocketTTSModelManager.installedVoices().first ?? settingsStore.ttsVoice
    }

    var keyVoxSpeakHelpPresentation: KeyVoxSpeakSheetView.IntroPresentation {
        let hasInstalledSpeakAssets =
            pocketTTSModelManager.isSharedModelReady()
            && pocketTTSModelManager.isReady(for: effectiveTTSVoice)

        let hasUsedKeyVoxSpeak = SharedPaths.appGroupUserDefaults()?
            .bool(forKey: UserDefaultsKeys.App.hasUsedKeyVoxSpeak) ?? false

        return KeyVoxSpeakFlowRules.helpPresentation(
            hasInstalledSpeakAssets: hasInstalledSpeakAssets,
            hasUsedKeyVoxSpeak: hasUsedKeyVoxSpeak
        )
    }

    func handleKeyVoxSpeakHelpAction() {
        appHaptics.light()
        keyVoxSpeakIntroController.present(introPresentation: keyVoxSpeakHelpPresentation)
    }

    func handlePrimaryTTSAction() {
        if pocketTTSModelManager.isSharedModelReady() == false {
            switch pocketTTSModelManager.sharedModelInstallState {
            case .notInstalled:
                pocketTTSModelManager.installVoiceEnsuringSharedModel(effectiveTTSVoice)
            case .failed:
                pocketTTSModelManager.repairVoiceEnsuringSharedModel(effectiveTTSVoice)
            case .downloading, .installing, .ready:
                break
            }
            return
        }

        switch pocketTTSModelManager.installState(for: effectiveTTSVoice) {
        case .notInstalled:
            pocketTTSModelManager.downloadVoice(effectiveTTSVoice)
        case .failed:
            pocketTTSModelManager.repairVoiceIfNeeded(effectiveTTSVoice)
        case .downloading, .installing:
            break
        case .ready:
            appHaptics.light()
            audioModeCoordinator.handleSpeakClipboardFromApp()
        }
    }

    func handleSecondaryTTSAction() {
        if ttsManager.isPlaybackPaused {
            audioModeCoordinator.handleResumeTTS()
            return
        }

        if ttsManager.state == .playing {
            audioModeCoordinator.handlePauseTTS()
            return
        }

        audioModeCoordinator.handleReplayLastTTS()
    }

    func handleReplayScrub(_ progress: Double) {
        ttsManager.seekReplay(toProgress: progress)
    }
}
