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

    private func content(metrics: ReturnToHostLayoutMetrics) -> some View {
        VStack(spacing: metrics.spacing) {
            Spacer()

            VStack(spacing: -10) {
                Text("Swipe Back,")
                    .font(.appFont(50 * metrics.textScale, variant: .medium))
                Text("and speak.")
                    .font(.appFont(40 * metrics.textScale, variant: .light))
            }
            .foregroundColor(.white)
            .multilineTextAlignment(.center)

            if metrics.separatesHeadline {
                Spacer()
            }

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
                .offset(y: metrics.videoOffset)

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
            .offset(y: metrics.bodyOffset)

            Spacer()
        }
    }
}

#Preview {
    ReturnToHostView()
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
}
