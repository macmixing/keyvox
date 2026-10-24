import SwiftUI

struct PlaybackPreparationView: View {
    private enum DismissAnimation {
        static let duration = 0.34
    }

    @EnvironmentObject private var ttsManager: TTSManager
    @State private var isVideoReady = false
    @State private var contentOpacity = 1.0
    @State private var isDismissing = false

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ReturnToHostAdaptiveLayout(spacing: 28) { metrics in
                content(metrics: metrics)
            }

            VStack {
                HStack {
                    Spacer()

                    Button {
                        guard isDismissing == false else { return }
                        isDismissing = true

                        withAnimation(.easeInOut(duration: DismissAnimation.duration)) {
                            contentOpacity = 0
                        }

                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(DismissAnimation.duration))
                            ttsManager.dismissPlaybackPreparationView()
                            contentOpacity = 1
                            isDismissing = false
                        }
                    } label: {
                        Text("Dismiss")
                            .font(.appFont(14, variant: .light))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(minWidth: 44, minHeight: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel("Dismiss")
                    .padding(.top, 12)
                    .padding(.trailing, 20)
                }

                Spacer()
            }
        }
        .opacity(contentOpacity)
        .dynamicTypeSize(.xSmall ... .xxxLarge)
        .animation(.easeInOut(duration: 0.1), value: isVideoReady)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: ttsManager.playbackPreparationProgress)
        .animation(.easeInOut(duration: 0.2), value: ttsManager.playbackPreparationPhase)
    }

    private func content(metrics: ReturnToHostLayoutMetrics) -> some View {
        VStack(spacing: metrics.spacing) {
            Spacer()

            VStack(spacing: -10) {
                phaseText(primaryHeadlineLineOne, metrics: metrics)
                    .font(.appFont(42 * metrics.textScale, variant: .medium))
                phaseText(primaryHeadlineLineTwo, metrics: metrics)
                    .font(.appFont(30 * metrics.textScale, variant: .light))
            }
            .frame(maxWidth: 330)
            .foregroundColor(.white)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.72)

            if metrics.separatesHeadline {
                Spacer()
            }

            metrics.videoFrame(Color.clear)
                .overlay {
                    ZStack {
                        if shouldPlayVideo {
                            LoopingVideoPlayer(
                                videoName: "ReturnToHost",
                                isReady: $isVideoReady
                            )
                        }

                        Image("ReturnToHostPlaceholder")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .opacity(shouldPlayVideo && isVideoReady ? 0 : 1)
                    }
                }
                .offset(y: metrics.videoOffset)

            VStack(spacing: 14) {
                phaseText(statusTitle, metrics: metrics)
                    .font(.appFont(30 * metrics.textScale, variant: .medium))
                    .foregroundColor(.white)
                    .frame(maxWidth: 320)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                phaseText(statusBody, metrics: metrics)
                    .font(.appFont(20 * metrics.textScale, variant: .light))
                    .foregroundColor(Color(UIColor.systemGray))
                    .frame(maxWidth: 330)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                PlaybackPreparationProgressBar(progress: ttsManager.playbackPreparationProgress)
                    .frame(maxWidth: 320)
                    .padding(.top, 8)

                Text(progressLabel)
                    .font(.appFont(16 * metrics.textScale, variant: .medium))
                    .foregroundColor(progressAccentColor)
            }
            .offset(y: metrics.bodyOffset)

            Spacer()
        }
    }

    /// The phase's text; where the layout asks for it, laid out with room for every phase's text
    /// so the layout chosen stays the same as the phase changes.
    @ViewBuilder
    private func phaseText(
        _ text: (TTSManager.PlaybackPreparationPhase) -> String,
        metrics: ReturnToHostLayoutMetrics
    ) -> some View {
        if metrics.reservesStateText {
            let texts = TTSManager.PlaybackPreparationPhase.allCases.map { (phase: $0, text: text($0)) }
            ZStack {
                ForEach(texts, id: \.phase) { entry in
                    let isCurrent = entry.phase == ttsManager.playbackPreparationPhase
                    Text(entry.text)
                        .opacity(isCurrent ? 1 : 0)
                        .accessibilityHidden(isCurrent == false)
                }
            }
        } else {
            Text(text(ttsManager.playbackPreparationPhase))
        }
    }

    private func primaryHeadlineLineOne(for phase: TTSManager.PlaybackPreparationPhase) -> String {
        switch phase {
        case .preparing:
            return "Stay here,"
        case .readyToReturn:
            return "Speak is"
        }
    }

    private func primaryHeadlineLineTwo(for phase: TTSManager.PlaybackPreparationPhase) -> String {
        switch phase {
        case .preparing:
            return "Speak is almost ready."
        case .readyToReturn:
            return "ready to go."
        }
    }

    private func statusTitle(for phase: TTSManager.PlaybackPreparationPhase) -> String {
        switch phase {
        case .preparing:
            return "Preparing to Speak..."
        case .readyToReturn:
            return "Return to your app."
        }
    }

    private func statusBody(for phase: TTSManager.PlaybackPreparationPhase) -> String {
        switch phase {
        case .preparing:
            return "Wait here while KeyVox prepares to speak without interruptions."
        case .readyToReturn:
            return "Speak has started. You can listen in your original app now."
        }
    }

    private var progressLabel: String {
        "\(Int(ttsManager.playbackPreparationProgress * 100))%"
    }

    private var shouldPlayVideo: Bool {
        ttsManager.playbackPreparationPhase == .readyToReturn
    }

    private var progressAccentColor: Color {
        ttsManager.playbackPreparationProgress >= 1 ? .yellow : AppTheme.accent
    }
}

private struct PlaybackPreparationProgressBar: View {
    let progress: Double

    var body: some View {
        ProgressView(value: progress)
            .progressViewStyle(KeyVoxProgressStyle())
            .frame(height: 12)
    }
}

#Preview {
    PlaybackPreparationView()
        .environmentObject(AppServiceRegistry.shared.ttsManager)
}
