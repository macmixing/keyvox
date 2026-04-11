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

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: -10) {
                    Text(primaryHeadlineLineOne)
                        .font(.appFont(42, variant: .medium))
                    Text(primaryHeadlineLineTwo)
                        .font(.appFont(30, variant: .light))
                }
                .frame(maxWidth: 330)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.72)

                Spacer()

                ZStack {
                    if shouldPlayVideo {
                        LoopingVideoPlayer(
                            videoName: "ReturnToHost",
                            isReady: $isVideoReady
                        )
                        .frame(width: 350, height: 350)
                    }

                    Image("ReturnToHostPlaceholder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 350, height: 350)
                        .opacity(shouldPlayVideo && isVideoReady ? 0 : 1)
                }
                .offset(y: -30)

                VStack(spacing: 14) {
                    Text(statusTitle)
                        .font(.appFont(30, variant: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: 320)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text(statusBody)
                        .font(.appFont(20, variant: .light))
                        .foregroundColor(Color(UIColor.systemGray))
                        .frame(maxWidth: 330)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)

                    PlaybackPreparationProgressBar(progress: ttsManager.playbackPreparationProgress)
                        .frame(maxWidth: 320)
                        .padding(.top, 8)

                    Text(progressLabel)
                        .font(.appFont(16, variant: .medium))
                        .foregroundColor(progressAccentColor)
                }
                .offset(y: -5)

                Spacer()
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

    private var primaryHeadlineLineOne: String {
        switch ttsManager.playbackPreparationPhase {
        case .preparing:
            return "Stay here,"
        case .readyToReturn:
            return "Speak is"
        }
    }

    private var primaryHeadlineLineTwo: String {
        switch ttsManager.playbackPreparationPhase {
        case .preparing:
            return "Speak is almost ready."
        case .readyToReturn:
            return "ready to go."
        }
    }

    private var statusTitle: String {
        switch ttsManager.playbackPreparationPhase {
        case .preparing:
            return "Preparing to Speak..."
        case .readyToReturn:
            return "Return to your app."
        }
    }

    private var statusBody: String {
        switch ttsManager.playbackPreparationPhase {
        case .preparing:
            return "Wait here while KeyVox prepares to speak without interruptions."
        case .readyToReturn:
            return "Speak has started. Go back to your original app and keep listening there."
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
