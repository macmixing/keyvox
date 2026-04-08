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

                            ttsVoiceShortcutLabel
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack(spacing: 8) {
                        if showsTTSTranscriptToggle {
                            ttsTranscriptToggleButton
                                .padding(.trailing, 8)
                        }

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

                if let activeTTSInstallState {
                    switch activeTTSInstallState {
                    case .downloading(let progress), .installing(let progress):
                        ModelDownloadProgress(progress: progress, showLabel: false)
                    case .notInstalled, .ready, .failed:
                        EmptyView()
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

                if showsExpandedTTSTranscript {
                    ttsTranscriptPanel
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
}
