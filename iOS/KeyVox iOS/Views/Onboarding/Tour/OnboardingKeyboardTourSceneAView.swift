import SwiftUI

struct OnboardingKeyboardTourSceneAView: View {
    private enum Metrics {
        static let videoWidth: CGFloat = 200
        static let videoHeight: CGFloat = 300
        static let menuArtworkOffset: CGFloat = 20
        static let captionSpacing: CGFloat = 12
    }

    @State private var isVideoReady = false

    var body: some View {
        if SetupVideoCaption.isShown {
            // The caption keeps its full height and the video gives up height first, so on short
            // screens both stay above the input bar.
            VStack(spacing: Metrics.captionSpacing) {
                video
                    .frame(maxWidth: Metrics.videoWidth, maxHeight: Metrics.videoHeight)
                    .aspectRatio(Metrics.videoWidth / Metrics.videoHeight, contentMode: .fit)

                SetupVideoCaptionView(
                    text: String(localized: "In the list of keyboards, choose KeyVox.", comment: "Caption under the onboarding keyboard tour video that shows the keyboard list, shown in place of the video's English words. KeyVox is a brand name and stays in English.")
                )
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            video
                .frame(width: Metrics.videoWidth, height: Metrics.videoHeight)
                .offset(y: Metrics.menuArtworkOffset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var video: some View {
        LoopingVideoPlayer(
            videoName: "KeyVoxKeyboardSelection",
            isReady: $isVideoReady
        )
        .accessibilityHidden(true)
    }

    struct GuidanceView: View {
        private enum Metrics {
            static let fontSize: CGFloat = 17
            static let lineSpacing: CGFloat = 1
        }

        var body: some View {
            Text("Tap & hold the Globe, \n then select KeyVox.", comment: "Instruction in the onboarding keyboard tour for switching to the KeyVox keyboard; keep the line break. Globe is the keyboard switch key, use Apple's official name for it in this language. KeyVox is a brand name and stays in English.")
                .font(.appFont(Metrics.fontSize, variant: .light))
                .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
                .lineSpacing(Metrics.lineSpacing)
                .lineLimit(2)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    struct ArrowView: View {
        private enum Metrics {
            static let size: CGFloat = 44
            static let floatingOffset: CGFloat = 6
        }

        @State private var isFloating = false

        var body: some View {
            Image(systemName: "arrow.down")
                .font(.system(size: Metrics.size, weight: .heavy))
                .foregroundStyle(.yellow)
                .frame(width: Metrics.size, height: Metrics.size)
                .offset(y: isFloating ? Metrics.floatingOffset : -Metrics.floatingOffset)
                .animation(
                    .easeInOut(duration: 0.9).repeatForever(autoreverses: true),
                    value: isFloating
                )
                .onAppear {
                    isFloating = true
                }
                .onDisappear {
                    isFloating = false
                }
        }
    }
}
