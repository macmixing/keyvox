import SwiftUI

struct OnboardingKeyboardTourSceneAView: View {
    private enum Metrics {
        static let videoWidth: CGFloat = 200
        static let videoHeight: CGFloat = 300
        static let menuArtworkOffset: CGFloat = 20
    }

    @State private var isVideoReady = false

    var body: some View {
        LoopingVideoPlayer(
            videoName: "KeyVoxKeyboardSelection",
            isReady: $isVideoReady
        )
            .frame(width: Metrics.videoWidth, height: Metrics.videoHeight)
            .offset(y: Metrics.menuArtworkOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityHidden(true)
    }

    struct GuidanceView: View {
        private enum Metrics {
            static let fontSize: CGFloat = 17
            static let lineSpacing: CGFloat = 1
        }

        var body: some View {
            Text("Tap & hold the Globe, \n then select KeyVox.")
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
