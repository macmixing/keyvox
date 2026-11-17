import Foundation
import SwiftUI

extension KeyVoxSpeakSettingsView {
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
                        Text(verbatim: "KeyVox Speak")
                            .font(.appFont(18))
                            .foregroundStyle(.white)

                        Text(playbackVoiceSummaryText)
                            .font(.appFont(17))
                            .foregroundStyle(.yellow)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .trailing, spacing: 10) {
                        if installedPlaybackVoices.isEmpty {
                            Text("Install voice", comment: "Shown in place of the Change button on the KeyVox Speak card when no voice is installed yet.")
                                .font(.appFont(14))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(.top, 2)
                        } else {
                            PlaybackVoicePickerMenu(
                                voices: installedPlaybackVoices,
                                selection: installedVoiceSelection
                            ) {
                                Text("Change", comment: "Menu button on the KeyVox Speak card that opens the list of installed voices.")
                                    .font(.appFont(16))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.top, 2)
                        }
                    }
                }

                Divider()
                    .overlay(.white.opacity(0.22))

                HStack(alignment: .top, spacing: 12) {
                    Text(playbackVoiceDescriptionText)
                        .font(.appFont(15, variant: .light))
                        .foregroundStyle(.white.opacity(0.7))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if supportsTTSExpansion {
                        Button {
                            appHaptics.light()
                            withAnimation(SettingsTabView.sectionExpansionAnimation) {
                                isTTSSectionExpanded.toggle()
                            }
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
                    .allowsHitTesting(shouldShowExpandedTTSContent)
                    .accessibilityHidden(!shouldShowExpandedTTSContent)
                    .background(alignment: .top) {
                        if shouldShowExpandedTTSContent || ttsExpandedContentHeight == 0 {
                            ttsExpandedContentMeasurement
                        }
                    }

                if ttsPurchaseController.isTTSUnlocked == false {
                    Divider()
                        .overlay(.white.opacity(0.22))

                    ttsUnlockRow
                }
            }
        }
    }

    @ViewBuilder
    private var ttsExpandedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Divider()
                .overlay(.white.opacity(0.22))

            VStack(alignment: .leading, spacing: 16) {
                ttsSharedModelRow

                if pocketTTSModelManager.isSharedModelReady() {
                    Divider()
                        .overlay(.white.opacity(0.22))
                        .padding(.leading, 12)
                        .padding(.trailing, 12)

                    VStack(alignment: .leading, spacing: 14) {
                        ForEach(Array(AppSettingsStore.TTSVoice.userFacingCases.enumerated()), id: \.element) { index, voice in
                            ttsVoiceRow(for: voice)

                            if index < AppSettingsStore.TTSVoice.userFacingCases.count - 1 {
                                Divider()
                                    .overlay(.white.opacity(0.22))
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
                Text("KeyVox Speak Unlimited", comment: "Title of the row for the purchase that removes the daily KeyVox Speak limit. KeyVox Speak is a brand name and stays in English.")
                    .font(.appFont(17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, alignment: .leading)

                AppActionButton(
                    title: String(localized: "Unlock", comment: "Button on the KeyVox Speak Unlimited row that opens the purchase."),
                    style: .primary,
                    size: .compact,
                    fontSize: 15,
                    action: {
                        appHaptics.light()
                        ttsPurchaseController.presentUnlockSheet()
                    }
                )
            }

            Text(ttsUnlockStatusText)
                .font(.appFont(14, variant: .light))
                .foregroundStyle(.white.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Speak currently supports English only.", comment: "Note on the KeyVox Speak card explaining that reading aloud only supports English. Speak is a brand name and stays in English.")
                .font(.appFont(13, variant: .light))
                .foregroundStyle(.yellow.opacity(0.7))
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    @ViewBuilder
    private var ttsSharedModelRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Text("KeyVox Speak Engine", comment: "Title of the row for the downloadable text-to-speech engine. KeyVox Speak is a brand name and stays in English.")
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

            if InlineWarningRules.showsSettingsTTSCellularDownloadWarning(
                isOnCellular: downloadNetworkMonitor.isOnCellular,
                sharedModelState: pocketTTSModelManager.sharedModelInstallState
            ) {
                InlineWarningRow(text: InlineWarningRow.Copy.cellularDownloadRecommended)
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
        .accessibilityLabel(
            isPlaying
                ? String(localized: "Pause \(voice.displayName) preview", comment: "VoiceOver label for the button that pauses a voice sample. The placeholder is the voice name, which stays in English.")
                : String(localized: "Play \(voice.displayName) preview", comment: "VoiceOver label for the button that plays a voice sample. The placeholder is the voice name, which stays in English.")
        )
    }

    @ViewBuilder
    private var ttsSharedModelActionButton: some View {
        switch pocketTTSModelManager.sharedModelInstallState {
        case .notInstalled:
            AppActionButton(
                title: String(localized: "Download", comment: "Button on the KeyVox Speak Engine row that downloads the engine."),
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: !pocketTTSModelManager.isBusyInstallingAnotherTarget(sharedModel: true),
                action: { pendingDownloadConfirmation = .sharedTTSModel }
            )
        case .ready:
            AppActionButton(
                title: String(localized: "Delete", comment: "Button on the KeyVox Speak Engine row that deletes the engine and its voices."),
                style: .destructive,
                size: .compact,
                fontSize: 15,
                isEnabled: !pocketTTSModelManager.isBusyInstallingAnotherTarget(sharedModel: true),
                action: { pendingDeletionConfirmation = .sharedTTSModel }
            )
        case .failed:
            AppActionButton(
                title: String(localized: "Repair", comment: "Button on the KeyVox Speak Engine row that retries a failed install."),
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
                title: String(localized: "Download", comment: "Button on a KeyVox Speak voice row that downloads the voice."),
                style: .primary,
                size: .compact,
                fontSize: 15,
                isEnabled: pocketTTSModelManager.isSharedModelReady() && !isBlockedByAnotherActiveInstall,
                action: { pendingDownloadConfirmation = .ttsVoice(voice) }
            )
        case .ready:
            AppActionButton(
                title: String(localized: "Delete", comment: "Button on a KeyVox Speak voice row that deletes the voice."),
                style: .destructive,
                size: .compact,
                fontSize: 15,
                isEnabled: !isBlockedByAnotherActiveInstall,
                action: { pendingDeletionConfirmation = .ttsVoice(voice) }
            )
        case .failed:
            AppActionButton(
                title: String(localized: "Repair", comment: "Button on a KeyVox Speak voice row that retries a failed install."),
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
            return String(localized: "Not installed (\(ApproximateDownloadSize.speakEngine))", comment: "Status on the KeyVox Speak Engine row when the engine is not installed. The value in parentheses is the approximate download size.")
        case .downloading:
            return String(localized: "Downloading KeyVox Speak engine.", comment: "Status on the KeyVox Speak Engine row while the engine downloads. KeyVox Speak is a brand name and stays in English.")
        case .installing:
            return String(localized: "Installing KeyVox Speak engine.", comment: "Status on the KeyVox Speak Engine row while the engine installs. KeyVox Speak is a brand name and stays in English.")
        case .ready:
            return String(localized: "Tap play to preview a voice.", comment: "Status on the KeyVox Speak Engine row once the engine is installed, pointing to the play buttons next to each voice.")
        case .failed:
            return String(localized: "Install failed", comment: "Status on the KeyVox Speak Engine row when the engine failed to install.")
        }
    }

    private func ttsVoiceStatusText(for voice: AppSettingsStore.TTSVoice, state: PocketTTSInstallState) -> String {
        switch state {
        case .downloading:
            return String(localized: "Downloading \(voice.displayName)", comment: "Status on a KeyVox Speak voice row while the voice downloads. The placeholder is the voice name, which stays in English.")
        case .installing:
            return String(localized: "Installing \(voice.displayName)", comment: "Status on a KeyVox Speak voice row while the voice installs. The placeholder is the voice name, which stays in English.")
        case .ready:
            return String(localized: "Installed", comment: "Status on a KeyVox Speak voice row when the voice is installed.")
        case .failed:
            return String(localized: "Install failed", comment: "Status on a KeyVox Speak voice row when the voice failed to install.")
        case .notInstalled:
            break
        }

        if pocketTTSModelManager.isSharedModelReady() == false {
            return String(localized: "Install the KeyVox Speak engine before downloading voices.", comment: "Status on a KeyVox Speak voice row when the engine is not installed yet. KeyVox Speak is a brand name and stays in English.")
        }

        let formattedSize = AppTypography.fontSupportedSpacing(ByteCountFormatter.string(
            fromByteCount: PocketTTSModelCatalog.approximateVoiceDownloadBytes(for: voice),
            countStyle: .file
        ))
        return String(localized: "Not installed (~\(formattedSize))", comment: "Status on a KeyVox Speak voice row when the voice is not installed. The placeholder is the approximate download size, already formatted with its unit.")
    }

    private func ttsProgressPercentageText(for state: PocketTTSInstallState) -> String? {
        let progress: Double
        switch state {
        case .downloading(let currentProgress), .installing(let currentProgress):
            progress = currentProgress
        case .notInstalled, .ready, .failed:
            return nil
        }

        return progress.formatted(.percent.precision(.fractionLength(0)).rounded(rule: .toNearestOrAwayFromZero))
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
        return String(localized: "No voice installed", comment: "Shown on the KeyVox Speak card in place of the selected voice name when no voice is installed.")
    }

    var playbackVoiceDescriptionText: String {
        if pocketTTSModelManager.isSharedModelReady() == false {
            return String(localized: "Install the KeyVox Speak engine first, then you can download voices.", comment: "Description on the KeyVox Speak card when the engine is not installed. KeyVox Speak is a brand name and stays in English.")
        }
        if installedPlaybackVoices.isEmpty {
            return String(localized: "Download a playback voice to let KeyVox read copied text aloud.", comment: "Description on the KeyVox Speak card when no voice is installed. KeyVox is a brand name and stays in English.")
        }
        return String(localized: "Choose which installed voice KeyVox uses when speaking copied text.", comment: "Description on the KeyVox Speak card when at least one voice is installed. KeyVox is a brand name and stays in English.")
    }

    var ttsUnlockStatusText: String {
        let remainingFreeSpeaks = ttsPurchaseController.remainingFreeTTSSpeaksToday
        return String(localized: "\(remainingFreeSpeaks) free speaks left today. Replay stays free for anything already generated.", comment: "Status on the KeyVox Speak Unlimited row in Speak settings showing how many free uses are left today. %lld is the number left; use plural forms. KeyVox Speak is a brand name and stays in English.")
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
