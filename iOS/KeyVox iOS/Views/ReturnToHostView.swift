import Foundation
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
                        Text("Dismiss", comment: "Button that closes the screen asking the user to swipe back to their app to dictate.")
                            .font(.appFont(14, variant: .light))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .frame(minWidth: 44, minHeight: 44, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "Dismiss", comment: "VoiceOver label for the button that closes the screen asking the user to swipe back to their app to dictate."))
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
            Text("Swipe Back,", comment: "First line of the two-line headline asking the user to swipe back to the app they came from; the second line is \"and speak.\"")
                .font(.appFont(50 * metrics.textScale, variant: .medium))
            Text("and speak.", comment: "Second line of the two-line headline; the first line is \"Swipe Back,\". Speak is a verb here, meaning start talking to dictate.")
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
            Text("KeyVox is ready...", comment: "Title on the screen asking the user to swipe back to their app to dictate. KeyVox is a brand name and stays in English.")
                .font(.appFont(35 * metrics.textScale, variant: .medium))
                .foregroundColor(.white)

            VStack(spacing: -4) {
                Text("Don’t worry, you’ll only have to", comment: "First line of a two-line message on the swipe back screen; the second line is \"do this once per session.\"")
                Text("do this once per session.", comment: "Second line of a two-line message on the swipe back screen; the first line is \"Don’t worry, you’ll only have to\". A session is the period while dictation stays turned on.")
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
