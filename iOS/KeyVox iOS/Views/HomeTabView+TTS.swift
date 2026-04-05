import SwiftUI

extension HomeTabView {
    @ViewBuilder
    var speakClipboardSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Speak Copied Text")
                            .font(.appFont(17))
                            .foregroundStyle(.white)

                        HStack(alignment: .center, spacing: 6) {
                            Image(systemName: "waveform")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.yellow)

                            Text(effectiveTTSVoice.displayName)
                                .font(.appFont(15, variant: .light))
                                .foregroundStyle(.yellow)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        if ttsManager.isActive {
                            Button(action: handlePrimaryTTSAction) {
                                ZStack {
                                    Circle()
                                        .fill(Color.yellow)

                                    Image(systemName: "stop.fill")
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundStyle(.black)
                                }
                                .frame(width: 44, height: 44)
                                .shadow(color: .yellow.opacity(0.3), radius: 10)
                            }
                            .buttonStyle(.plain)
                            .transition(.scale.combined(with: .opacity))
                            if showsTTSTransportButton {
                                ttsTransportButton
                            }
                        } else {
                            if showsTTSTransportButton {
                                ttsTransportButton
                            }

                            AppActionButton(
                                title: ttsButtonTitle,
                                style: .primary,
                                size: .compact,
                                fontSize: 15,
                                isEnabled: isTTSButtonEnabled,
                                action: handlePrimaryTTSAction
                            )
                            .transition(.scale.combined(with: .opacity))
                        }
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    if showsReplayScrubber {
                        TTSReplayScrubber(
                            progress: ttsManager.playbackProgress,
                            currentTimeSeconds: ttsManager.replayCurrentTimeSeconds,
                            durationSeconds: ttsManager.replayDurationSeconds,
                            onScrub: handleReplayScrub
                        )
                    } else {
                        Text(ttsStatusText)
                            .font(.appFont(14, variant: .light))
                            .foregroundStyle(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)

                        if let preparationPercentageText = ttsPreparationPercentageText {
                            Text(preparationPercentageText)
                                .font(.appFont(14, variant: .medium))
                                .foregroundStyle(.yellow)
                        }
                    }
                }

                if showsTTSPreparationSlot {
                    VStack(alignment: .leading, spacing: 8) {
                        ProgressView(value: ttsManager.playbackPreparationProgress)
                            .progressViewStyle(KeyVoxProgressStyle())
                            .frame(height: 12)
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

    var ttsTransportButton: some View {
        Button(action: handleSecondaryTTSAction) {
            ZStack {
                Circle()
                    .fill(Color.yellow)

                Circle()
                    .trim(from: 0, to: ttsTransportPlaybackProgress)
                    .stroke(
                        Color.indigo,
                        style: StrokeStyle(lineWidth: 4, lineCap: .butt)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(2)
                    .opacity(showsTTSTransportProgressRing ? 1 : 0)

                Image(systemName: ttsTransportSymbolName)
                    .font(.system(size: 22, weight: ttsTransportSymbolWeight))
                    .foregroundStyle(.black)
            }
            .overlay(alignment: .topTrailing) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(ttsTransportBadgeColor)
                    .background(Circle().fill(Color.black))
                    .offset(x: 3, y: -1)
                    .opacity(showsTTSTransportBadge ? 1 : 0)
                    .scaleEffect(showsTTSTransportBadge ? 1 : 0.82)
            }
            .frame(width: 44, height: 44)
            .shadow(color: .yellow.opacity(0.3), radius: 10)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.22), value: showsTTSTransportBadge)
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
            return ttsManager.isActive ? "Stop" : "Speak"
        }
    }

    var showsTTSTransportButton: Bool {
        if ttsManager.state == .preparing || ttsManager.state == .generating {
            return false
        }

        return ttsManager.isActive || ttsManager.hasReplayablePlayback
    }

    var showsFastModeBackgroundSafetyCheckmark: Bool {
        settingsStore.fastPlaybackModeEnabled
            && ttsManager.state == .playing
            && !ttsManager.isReplayingCachedPlayback
            && ttsManager.isFastModeBackgroundSafe
    }

    var showsReplayReadyCheckmark: Bool {
        ttsManager.isCurrentRequestReplayReady
            && ttsManager.isActive
            && !ttsManager.isReplayingCachedPlayback
    }

    var showsTTSTransportBadge: Bool {
        showsReplayReadyCheckmark || showsFastModeBackgroundSafetyCheckmark
    }

    var ttsTransportBadgeColor: Color {
        if showsReplayReadyCheckmark {
            return .green
        }
        return .blue
    }

    var showsTTSTransportProgressRing: Bool {
        ttsManager.state == .playing && !ttsManager.isReplayingCachedPlayback
    }

    var ttsTransportPlaybackProgress: CGFloat {
        CGFloat(min(1, max(0, ttsManager.playbackProgress)))
    }

    var ttsTransportSymbolName: String {
        if ttsManager.isPlaybackPaused {
            return "play.fill"
        }
        if ttsManager.state == .playing {
            return "pause.fill"
        }
        return "repeat"
    }

    var ttsTransportSymbolWeight: Font.Weight {
        .medium
    }

    var showsReplayScrubber: Bool {
        ttsManager.isReplayingCachedPlayback
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

        switch pocketTTSModelManager.installState(for: effectiveTTSVoice) {
        case .notInstalled:
            return "Install the \(effectiveTTSVoice.displayName) voice to read copied text aloud."
        case .downloading:
            return "Downloading the \(effectiveTTSVoice.displayName) voice..."
        case .installing:
            return "Installing the \(effectiveTTSVoice.displayName) voice..."
        case .failed:
            return "\(effectiveTTSVoice.displayName) voice install failed."
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
            return ttsManager.isPlaybackPaused ? "Playback paused." : "Speaking copied text."
        case .finished:
            return "Finished speaking."
        case .error:
            return "Playback failed."
        }
    }

    var ttsErrorText: String? {
        guard let lastErrorMessage = ttsManager.lastErrorMessage else { return nil }

        if lastErrorMessage.localizedCaseInsensitiveContains("unable to compute the prediction using a neural network model")
            || lastErrorMessage.localizedCaseInsensitiveContains("broken/unsupported model")
            || lastErrorMessage.localizedCaseInsensitiveContains("error code -1") {
            return "Playback could not continue after the app moved to the background."
        }

        return lastErrorMessage
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

private struct TTSReplayScrubber: View {
    let progress: Double
    let currentTimeSeconds: Double
    let durationSeconds: Double
    let onScrub: (Double) -> Void

    @State private var scrubProgress: Double
    @State private var isScrubbing = false

    init(
        progress: Double,
        currentTimeSeconds: Double,
        durationSeconds: Double,
        onScrub: @escaping (Double) -> Void
    ) {
        self.progress = progress
        self.currentTimeSeconds = currentTimeSeconds
        self.durationSeconds = durationSeconds
        self.onScrub = onScrub
        _scrubProgress = State(initialValue: progress)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Slider(
                value: Binding(
                    get: { scrubProgress },
                    set: { scrubProgress = $0 }
                ),
                in: 0...1,
                onEditingChanged: handleEditingChanged
            )
            .tint(.yellow)
            .animation(.linear(duration: 1.0 / 30.0), value: scrubProgress)

            HStack(spacing: 12) {
                Text(formattedTime(isScrubbing ? durationSeconds * scrubProgress : currentTimeSeconds))
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(formattedTime(durationSeconds))
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .font(.appFont(13, variant: .medium))
            .foregroundStyle(.yellow.opacity(0.95))
            .monospacedDigit()
        }
        .onChange(of: progress, initial: true) { _, newValue in
            guard isScrubbing == false else { return }
            scrubProgress = newValue
        }
    }

    private func handleEditingChanged(_ editing: Bool) {
        isScrubbing = editing
        if editing == false {
            onScrub(scrubProgress)
        }
    }

    private func formattedTime(_ seconds: Double) -> String {
        let clampedSeconds = max(0, Int(seconds.rounded(.down)))
        let minutes = clampedSeconds / 60
        let remainingSeconds = clampedSeconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}
