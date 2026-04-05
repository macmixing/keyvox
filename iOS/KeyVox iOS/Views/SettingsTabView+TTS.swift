import SwiftUI

extension SettingsTabView {
    @ViewBuilder
    var ttsSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accent.opacity(0.4))
                            .frame(width: 32, height: 32)

                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.yellow)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Voice Model")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(playbackVoiceSummaryText)
                            .font(.appFont(17))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 10) {
                        if installedPlaybackVoices.isEmpty {
                            Text("Install voice")
                                .font(.appFont(14))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 2)
                        } else {
                            PlaybackVoicePickerMenu(
                                voices: installedPlaybackVoices,
                                selection: installedVoiceSelection
                            ) {
                                Text("Change")
                                    .font(.appFont(16))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                HStack(alignment: .center, spacing: 12) {
                    Text(playbackVoiceDescriptionText)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if supportsTTSExpansion {
                        Button {
                            appHaptics.light()
                            isTTSSectionExpanded.toggle()
                        } label: {
                            Image(systemName: isTTSSectionExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 28, weight: .heavy))
                                .foregroundStyle(.yellow)
                                .frame(width: 56, height: 56)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                ttsExpandedContent
                    .frame(height: shouldShowExpandedTTSContent ? ttsExpandedContentHeight : 0, alignment: .top)
                    .clipped()
                    .opacity(shouldShowExpandedTTSContent ? 1 : 0)
                    .allowsHitTesting(shouldShowExpandedTTSContent)
                    .accessibilityHidden(!shouldShowExpandedTTSContent)
                    .background(alignment: .top) {
                        if shouldShowExpandedTTSContent || ttsExpandedContentHeight == 0 {
                            ttsExpandedContentMeasurement
                        }
                    }

                Divider()
                    .background(.white.opacity(0.22))

                ttsUnlockRow
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: shouldShowExpandedTTSContent)
        .animation(.spring(response: 0.42, dampingFraction: 0.84), value: ttsExpandedContentHeight)
    }

    @ViewBuilder
    private var ttsExpandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .background(.white.opacity(0.4))

            VStack(alignment: .leading, spacing: 16) {
                ttsSharedModelRow

                if pocketTTSModelManager.isSharedModelReady() {
                    Divider()
                        .background(.white.opacity(0.22))
                        .padding(.leading, 12)
                        .padding(.trailing, 12)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(AppSettingsStore.TTSVoice.allCases.enumerated()), id: \.element) { index, voice in
                            ttsVoiceRow(for: voice)

                            if index < AppSettingsStore.TTSVoice.allCases.count - 1 {
                                Divider()
                                    .background(.white.opacity(0.22))
                                    .padding(.leading, 12)
                                    .padding(.trailing, 12)
                            }
                        }
                    }
                }
            }
        }
    }

    private var ttsExpandedContentMeasurement: some View {
        ttsExpandedContent
            .fixedSize(horizontal: false, vertical: true)
            .hidden()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            updateTTSExpandedContentHeight(geometry.size.height)
                        }
                        .onChange(of: geometry.size.height) { _, newHeight in
                            updateTTSExpandedContentHeight(newHeight)
                        }
                }
            )
    }

    @ViewBuilder
    private var ttsUnlockRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text("KeyVox Speak Unlimited")
                    .font(.appFont(17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                if ttsPurchaseController.isTTSUnlocked {
                    Text("Unlocked")
                        .font(.appFont(15))
                        .foregroundStyle(.yellow)
                } else {
                    AppActionButton(
                        title: "Unlock",
                        style: .primary,
                        size: .compact,
                        fontSize: 15,
                        action: {
                            appHaptics.light()
                            ttsPurchaseController.presentUnlockSheet()
                        }
                    )
                }
            }

            Text(ttsUnlockStatusText)
                .font(.appFont(14, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var ttsSharedModelRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text("PocketTTS CoreML")
                    .font(.appFont(17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ttsSharedModelActionButton
            }

            HStack(alignment: .center, spacing: 12) {
                Text(ttsSharedModelStatusText)
                    .font(.appFont(14, variant: .light))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)

                if let percentageText = ttsProgressPercentageText(for: pocketTTSModelManager.sharedModelInstallState) {
                    Text(percentageText)
                        .font(.appFont(14, variant: .medium))
                        .foregroundStyle(.yellow)
                }
            }

            if case .failed(let message) = pocketTTSModelManager.sharedModelInstallState {
                Text(message)
                    .font(.appFont(12))
                    .foregroundStyle(.red)
            }

            switch pocketTTSModelManager.sharedModelInstallState {
            case .downloading(let progress), .installing(let progress):
                ModelDownloadProgress(progress: progress, showLabel: false)
            case .notInstalled, .ready, .failed:
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private func ttsVoiceRow(for voice: AppSettingsStore.TTSVoice) -> some View {
        let state = pocketTTSModelManager.installState(for: voice)

        HStack(alignment: .center, spacing: 12) {
            ttsVoicePreviewButton(for: voice)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 12) {
                    HStack(alignment: .center, spacing: 8) {
                        Text(voice.displayName)
                            .font(.appFont(17))
                            .foregroundStyle(.white)

                        if settingsStore.ttsVoice == voice && pocketTTSModelManager.isReady(for: voice) {
                            Circle()
                                .fill(.yellow)
                                .frame(width: 8, height: 8)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    ttsVoiceActionButton(for: voice, state: state)
                }

                HStack(alignment: .center, spacing: 12) {
                    Text(ttsVoiceStatusText(for: voice, state: state))
                        .font(.appFont(14, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if let percentageText = ttsProgressPercentageText(for: state) {
                        Text(percentageText)
                            .font(.appFont(14, variant: .medium))
                            .foregroundStyle(.yellow)
                    }
                }

                if case .failed(let message) = state {
                    Text(message)
                        .font(.appFont(12))
                        .foregroundStyle(.red)
                }

                switch state {
                case .downloading(let progress), .installing(let progress):
                    ModelDownloadProgress(progress: progress, showLabel: false)
                case .notInstalled, .ready, .failed:
                    EmptyView()
                }
            }
        }
    }

    @ViewBuilder
    private func ttsVoicePreviewButton(for voice: AppSettingsStore.TTSVoice) -> some View {
        let isActive = ttsPreviewPlayer.isActive(for: voice)
        let isPlaying = isActive && ttsPreviewPlayer.isPlaying
        let symbolName = isPlaying ? "pause.circle" : "play.circle"
        let canPlayPreview = ttsPreviewPlayer.hasPreview(for: voice)

        Button {
            ttsPreviewPlayer.togglePlayback(for: voice)
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 26, weight: .regular))
                .foregroundStyle(canPlayPreview ? .yellow : .white.opacity(0.28))
                .frame(width: 32, height: 32)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!canPlayPreview)
        .accessibilityLabel(isPlaying ? "Pause \(voice.displayName) preview" : "Play \(voice.displayName) preview")
    }

    @ViewBuilder
    private var ttsSharedModelActionButton: some View {
        switch pocketTTSModelManager.sharedModelInstallState {
        case .notInstalled:
            AppActionButton(
                title: "Install",
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: !pocketTTSModelManager.isBusyInstallingAnotherTarget(sharedModel: true),
                action: { pocketTTSModelManager.downloadSharedModel() }
            )
        case .ready:
            AppActionButton(
                title: "Delete",
                style: .destructive,
                size: .compact,
                fontSize: 15,
                isEnabled: !pocketTTSModelManager.isBusyInstallingAnotherTarget(sharedModel: true),
                action: { pendingDeletionConfirmation = .sharedTTSModel }
            )
        case .failed:
            AppActionButton(
                title: "Repair",
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: !pocketTTSModelManager.isBusyInstallingAnotherTarget(sharedModel: true),
                action: { pocketTTSModelManager.repairSharedModelIfNeeded() }
            )
        case .downloading, .installing:
            EmptyView()
        }
    }

    @ViewBuilder
    private func ttsVoiceActionButton(for voice: AppSettingsStore.TTSVoice, state: PocketTTSInstallState) -> some View {
        let isBlockedByAnotherActiveInstall = pocketTTSModelManager.isBusyInstallingAnotherTarget(voice: voice)

        switch state {
        case .notInstalled:
            AppActionButton(
                title: "Install",
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: pocketTTSModelManager.isSharedModelReady() && !isBlockedByAnotherActiveInstall,
                action: { pocketTTSModelManager.downloadVoice(voice) }
            )
        case .ready:
            AppActionButton(
                title: "Delete",
                style: .destructive,
                size: .compact,
                fontSize: 15,
                isEnabled: !isBlockedByAnotherActiveInstall,
                action: { pendingDeletionConfirmation = .ttsVoice(voice) }
            )
        case .failed:
            AppActionButton(
                title: "Repair",
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: pocketTTSModelManager.isSharedModelReady() && !isBlockedByAnotherActiveInstall,
                action: { pocketTTSModelManager.repairVoiceIfNeeded(voice) }
            )
        case .downloading, .installing:
            EmptyView()
        }
    }

    private var ttsSharedModelStatusText: String {
        switch pocketTTSModelManager.sharedModelInstallState {
        case .notInstalled:
            return "Not installed (~642 MB)"
        case .downloading:
            return "Downloading PocketTTS CoreML"
        case .installing:
            return "Installing PocketTTS CoreML"
        case .ready:
            return "Installed"
        case .failed:
            return "Install failed"
        }
    }

    private func ttsVoiceStatusText(for voice: AppSettingsStore.TTSVoice, state: PocketTTSInstallState) -> String {
        switch state {
        case .downloading:
            return "Downloading \(voice.displayName)"
        case .installing:
            return "Installing \(voice.displayName)"
        case .ready:
            return "Installed"
        case .failed:
            return "Install failed"
        case .notInstalled:
            break
        }

        if pocketTTSModelManager.isSharedModelReady() == false {
            return "Install PocketTTS CoreML before downloading voices."
        }

        let formattedSize = ByteCountFormatter.string(
            fromByteCount: PocketTTSModelCatalog.approximateVoiceDownloadBytes(for: voice),
            countStyle: .file
        )
        return "Not installed (~\(formattedSize))"
    }

    private func ttsProgressPercentageText(for state: PocketTTSInstallState) -> String? {
        let progress: Double
        switch state {
        case .downloading(let currentProgress), .installing(let currentProgress):
            progress = currentProgress
        case .notInstalled, .ready, .failed:
            return nil
        }

        return "\(Int((progress * 100).rounded()))%"
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
                settingsStore.ttsVoice = newValue
            }
        )
    }

    var playbackVoiceSummaryText: String {
        if installedPlaybackVoices.contains(settingsStore.ttsVoice) {
            return settingsStore.ttsVoice.displayName
        }
        if let firstInstalledVoice = installedPlaybackVoices.first {
            return firstInstalledVoice.displayName
        }
        return "No voice installed"
    }

    var playbackVoiceDescriptionText: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            return "Install PocketTTS CoreML first. Once it is ready, you can download individual playback voices."
        }
        if installedPlaybackVoices.isEmpty {
            return "Download a playback voice to let KeyVox read copied text aloud."
        }
        return "Choose which installed PocketTTS voice KeyVox uses when speaking copied text."
    }

    var ttsUnlockStatusText: String {
        if ttsPurchaseController.isTTSUnlocked {
            return "Unlimited copied-text playback is enabled on this Apple account."
        }

        let remainingFreeSpeaks = ttsPurchaseController.remainingFreeTTSSpeaksToday
        let noun = remainingFreeSpeaks == 1 ? "speak" : "speaks"
        return "\(remainingFreeSpeaks) free \(noun) left today. Replay stays free for anything already generated."
    }

    var supportsTTSExpansion: Bool {
        pocketTTSModelManager.isSharedModelReady()
    }

    var shouldShowExpandedTTSContent: Bool {
        if pocketTTSModelManager.isSharedModelReady() == false {
            return true
        }
        return isTTSSectionExpanded
    }

    func updateTTSExpandedContentHeight(_ newHeight: CGFloat) {
        guard newHeight > 0 else { return }
        if abs(ttsExpandedContentHeight - newHeight) > 0.5 {
            ttsExpandedContentHeight = newHeight
        }
    }
}
