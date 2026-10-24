import SwiftUI

struct ReturnToHostView: View {
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @State private var isVideoReady = false

    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()

            ReturnToHostAdaptiveLayout(spacing: 30) { metrics in
                content(metrics: metrics)
            }

            VStack {
                HStack {
                    Spacer()

                    Button {
                        transcriptionManager.isReturnToHostViewPresented = false
                    } label: {
                        Text("Dismiss")
                            .font(.appFont(14, variant: .light))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(minWidth: 44, minHeight: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss")
                    .padding(.top, 12)
                    .padding(.trailing, 20)
                }

                Spacer()
            }
        }
        .dynamicTypeSize(.xSmall ... .xxxLarge)
        .animation(.easeInOut(duration: 0.1), value: isVideoReady)
    }

    @ViewBuilder
    private func content(metrics: ReturnToHostLayoutMetrics) -> some View {
        if metrics.isSideBySide {
            ReturnToHostSideBySideLayout(metrics: metrics) {
                VStack(spacing: 24) {
                    headline(metrics: metrics)
                    message(metrics: metrics)
                }
            } video: {
                video(metrics: metrics)
            }
        } else {
            VStack(spacing: metrics.spacing) {
                Spacer()

                headline(metrics: metrics)

                if metrics.separatesHeadline {
                    Spacer()
                }

                video(metrics: metrics)
                    .offset(y: metrics.videoOffset)

                message(metrics: metrics)
                    .offset(y: metrics.bodyOffset)

                Spacer()
            }
        }
    }

    private func headline(metrics: ReturnToHostLayoutMetrics) -> some View {
        VStack(spacing: -10) {
            Text("Swipe Back,")
                .font(.appFont(50 * metrics.textScale, variant: .medium))
            Text("and speak.")
                .font(.appFont(40 * metrics.textScale, variant: .light))
        }
        .foregroundColor(.white)
        .multilineTextAlignment(.center)
    }

    private func video(metrics: ReturnToHostLayoutMetrics) -> some View {
        metrics.videoFrame(Color.clear)
            .overlay {
                ZStack {
                    LoopingVideoPlayer(
                        videoName: "ReturnToHost",
                        isReady: $isVideoReady
                    )

                    // Static image is now bit-perfect because we generated it with AVFoundation on the Mac
                    Image("ReturnToHostPlaceholder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .opacity(isVideoReady ? 0 : 1)
                }
            }
    }

    private func message(metrics: ReturnToHostLayoutMetrics) -> some View {
        VStack(spacing: 8) {
            Text("KeyVox is ready...")
                .font(.appFont(35 * metrics.textScale, variant: .medium))
                .foregroundColor(.white)

            VStack(spacing: -4) {
                Text("Don’t worry, you’ll only have to")
                Text("do this once per session.")
            }
            .font(.appFont(22 * metrics.textScale, variant: .light))
            .foregroundColor(Color(UIColor.systemGray))
            .multilineTextAlignment(.center)
        }
    }
}

#Preview {
    ReturnToHostView()
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
}
