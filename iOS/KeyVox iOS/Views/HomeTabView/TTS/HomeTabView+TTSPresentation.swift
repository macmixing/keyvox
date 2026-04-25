import SwiftUI

enum TTSPreparationPresentationPolicy {
    static func showsProgress(
        state: KeyVoxTTSState,
        progress: Double,
        visibleThreshold: Double,
        isWarmStart: Bool
    ) -> Bool {
        guard state == .preparing || state == .generating else { return false }
        return isWarmStart || progress >= visibleThreshold
    }

    static func showsSpinner(
        state: KeyVoxTTSState,
        progress: Double,
        visibleThreshold: Double,
        isWarmStart: Bool
    ) -> Bool {
        guard state == .preparing || state == .generating else { return false }
        return showsProgress(
            state: state,
            progress: progress,
            visibleThreshold: visibleThreshold,
            isWarmStart: isWarmStart
        ) == false
    }
}

extension HomeTabView {
    var ttsPreparationSlotHeight: CGFloat {
        12
    }

    var ttsPreparationSlotAnimationDurationSeconds: Double {
        0.2
    }

    private var ttsPreparationVisibleProgressThreshold: Double {
        0.02
    }

    private var ttsPreparationRevealDelaySeconds: Double {
        showsTTSPreparationProgress ? 0.02 : 0.5
    }

    private var ttsPreparationFadeOutWaitNanoseconds: UInt64 {
        240_000_000
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

    var ttsVoiceReadinessIconName: String {
        if settingsStore.speakTimeoutTiming.keepsRuntimeWarmIndefinitely,
           isTTSVoiceReadyIndicatorActive {
            return "infinity.circle"
        }

        return "waveform"
    }

    var ttsVoiceReadinessColor: Color {
        return isTTSVoiceReadyIndicatorActive ? Color.yellow : Color.white
    }

    private var isTTSVoiceReadyIndicatorActive: Bool {
        switch ttsManager.state {
        case .preparing, .generating:
            return showsTTSPreparationProgress
        case .idle, .playing, .finished, .error:
            return ttsManager.engine.isPreparedForSynthesis
        }
    }

    var ttsButtonTitle: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            return "Download"
        }

        switch pocketTTSModelManager.installState(for: effectiveTTSVoice) {
        case .notInstalled:
            return "Download"
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
        TTSPreparationPresentationPolicy.showsProgress(
            state: ttsManager.state,
            progress: ttsManager.playbackPreparationProgress,
            visibleThreshold: ttsPreparationVisibleProgressThreshold,
            isWarmStart: ttsManager.isCurrentPlaybackWarmStart
        )
    }

    var showsPrimaryTTSLoadingSpinner: Bool {
        TTSPreparationPresentationPolicy.showsSpinner(
            state: ttsManager.state,
            progress: ttsManager.playbackPreparationProgress,
            visibleThreshold: ttsPreparationVisibleProgressThreshold,
            isWarmStart: ttsManager.isCurrentPlaybackWarmStart
        )
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
        isTTSPreparationSlotExpanded = showsTTSPreparationProgress
        isTTSPreparationVisible = showsTTSPreparationProgress
    }

    func updateTTSPreparationPresentation() {
        ttsPreparationRevealToken = UUID()
        ttsPreparationCollapseTask?.cancel()

        if showsTTSPreparationProgress {
            if showsTTSPreparationSlot == false {
                showsTTSPreparationSlot = true
                isTTSPreparationSlotExpanded = false

                DispatchQueue.main.async {
                    guard showsTTSPreparationProgress else { return }

                    withAnimation(.easeInOut(duration: ttsPreparationSlotAnimationDurationSeconds)) {
                        isTTSPreparationSlotExpanded = true
                    }
                }
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
            try? await Task.sleep(nanoseconds: ttsPreparationFadeOutWaitNanoseconds)
            guard Task.isCancelled == false else { return }

            withAnimation(.easeInOut(duration: ttsPreparationSlotAnimationDurationSeconds)) {
                isTTSPreparationSlotExpanded = false
            }

            try? await Task.sleep(
                nanoseconds: UInt64(ttsPreparationSlotAnimationDurationSeconds * 1_000_000_000)
            )
            guard Task.isCancelled == false else { return }
            showsTTSPreparationSlot = false
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
