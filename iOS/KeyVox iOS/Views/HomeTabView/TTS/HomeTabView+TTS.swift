import SwiftUI

extension HomeTabView {
    private var speakClipboardTitleFirstLineCenterOffset: CGFloat {
        let fontSize: CGFloat = 17
        let font: UIFont

        if let name = AppTypography.resolvedFontName(for: fontSize, variant: .medium),
           let resolvedFont = UIFont(name: name, size: fontSize) {
            font = resolvedFont
        } else {
            font = .systemFont(ofSize: fontSize, weight: .medium)
        }

        return font.ascender - (font.lineHeight / 2)
    }

    @ViewBuilder
    var speakClipboardSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .speakClipboardTitleFirstLineCenter, spacing: 4) {
                            Text("Speak Copied Text")
                                .font(.appFont(17))
                                .foregroundStyle(.white)
                                .alignmentGuide(.speakClipboardTitleFirstLineCenter) { dimensions in
                                    dimensions[.firstTextBaseline] - speakClipboardTitleFirstLineCenterOffset
                                }

                            Button(action: handleKeyVoxSpeakHelpAction) {
                                Image(systemName: "questionmark.circle")
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundStyle(.yellow)
                                    .frame(width: 16, height: 16)
                                    .contentShape(Rectangle())
                                    .padding(8)
                            }
                            .buttonStyle(.plain)
                            .frame(width: 32, height: 32)
                            .accessibilityLabel("Learn about KeyVox Speak")
                            .alignmentGuide(.speakClipboardTitleFirstLineCenter) { dimensions in
                                dimensions[VerticalAlignment.center]
                            }
                        }

                        HStack(alignment: .center, spacing: 6) {
                            Image(systemName: "waveform")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(ttsVoiceReadinessColor)

                            ttsVoiceShortcutLabel
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(alignment: .center, spacing: 8) {
                        if showsTTSTranscriptToggle {
                            ttsTranscriptToggleButton
                                .padding(.trailing, 8)
                        }

                        if ttsManager.isActive {
                            Button(action: handlePrimaryTTSAction) {
                                ZStack {
                                    Circle()
                                        .fill(Color.yellow)

                                    if showsPrimaryTTSLoadingSpinner {
                                        NativeActivityIndicator(
                                            color: .black,
                                            style: .medium
                                        )
                                            .frame(width: 18, height: 18)
                                            .transition(.opacity)
                                    } else {
                                        Image(systemName: "stop.fill")
                                            .font(.system(size: 18, weight: .medium))
                                            .foregroundStyle(.black)
                                            .transition(.opacity)
                                    }
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

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: 12) {
                        if showsReplayScrubber {
                            TTSReplayScrubber(
                                progress: ttsManager.playbackProgress,
                                currentTimeSeconds: ttsManager.replayCurrentTimeSeconds,
                                durationSeconds: ttsManager.replayDurationSeconds,
                                onScrub: handleReplayScrub
                            )
                        } else {
                            ZStack(alignment: .topLeading) {
                                HStack(alignment: .center, spacing: 12) {
                                    Text(ttsStatusText)
                                        .font(.appFont(14, variant: .light))
                                        .foregroundStyle(.white.opacity(0.7))
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .opacity(showsPrimaryTTSStatusRow ? 1 : 0)

                                    if let preparationPercentageText = ttsPreparationPercentageText {
                                        Text(preparationPercentageText)
                                            .font(.appFont(14, variant: .medium))
                                            .foregroundStyle(.yellow)
                                            .opacity(showsPrimaryTTSStatusRow ? 1 : 0)
                                    }
                                }
                                .animation(.easeInOut(duration: 0.2), value: showsPrimaryTTSStatusRow)

                                if mountsFastModeBackgroundSafetyWarningRow,
                                   let mountedTTSWarningText {
                                    InlineWarningRow(text: mountedTTSWarningText)
                                        .opacity(showsFastModeBackgroundSafetyWarningRow ? 1 : 0)
                                        .animation(.easeInOut(duration: 0.2), value: showsFastModeBackgroundSafetyWarningRow)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                        }
                    }

                    if showsTTSCellularDownloadWarning {
                        InlineWarningRow(text: ttsCellularDownloadWarningText)
                    }
                }

                if let activeTTSInstallState {
                    switch activeTTSInstallState {
                    case .downloading(let progress), .installing(let progress):
                        ModelDownloadProgress(progress: progress, showLabel: false)
                    case .notInstalled, .ready, .failed:
                        EmptyView()
                    }
                }

                if showsTTSPreparationSlot {
                    Color.clear
                        .frame(
                            height: isTTSPreparationSlotExpanded ? ttsPreparationSlotHeight : 0,
                            alignment: .top
                        )
                        .overlay(alignment: .top) {
                            ProgressView(value: ttsManager.playbackPreparationProgress)
                                .progressViewStyle(KeyVoxProgressStyle(fillColor: ttsPreparationProgressColor))
                                .frame(height: ttsPreparationSlotHeight)
                                .opacity(isTTSPreparationVisible ? 1 : 0)
                        }
                        .allowsHitTesting(isTTSPreparationVisible)
                        .accessibilityHidden(!isTTSPreparationVisible)
                        .animation(.easeInOut(duration: ttsPreparationSlotAnimationDurationSeconds), value: isTTSPreparationSlotExpanded)
                }

                if showsExpandedTTSTranscript {
                    ttsTranscriptPanel
                        .transition(.scale(scale: 0.96, anchor: .top))

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

    private var ttsPreparationProgressColor: Color {
        settingsStore.fastPlaybackModeEnabled ? .yellow : AppTheme.accent
    }
}

private extension VerticalAlignment {
    private enum SpeakClipboardTitleFirstLineCenter: AlignmentID {
        static func defaultValue(in context: ViewDimensions) -> CGFloat {
            context[VerticalAlignment.center]
        }
    }

    static let speakClipboardTitleFirstLineCenter = VerticalAlignment(SpeakClipboardTitleFirstLineCenter.self)
}
