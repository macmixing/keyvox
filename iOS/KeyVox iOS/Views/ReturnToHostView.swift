import SwiftUI

struct ReturnToHostView: View {
    @EnvironmentObject private var transcriptionManager: TranscriptionManager
    @State private var isVideoReady = false
    
    var body: some View {
        ZStack {
            AppTheme.screenBackground.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                VStack(spacing: -10) {
                    Text("Swipe Back,")
                        .font(.appFont(50, variant: .medium))
                    Text("and speak.")
                        .font(.appFont(40, variant: .light))
                }
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                
                Spacer()
                
                ZStack {
                    LoopingVideoPlayer(
                        videoName: "ReturnToHost", 
                        isReady: $isVideoReady
                    )
                    .frame(width: 350, height: 350)

                    // Static image is now bit-perfect because we generated it with AVFoundation on the Mac
                    Image("ReturnToHostPlaceholder")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 350, height: 350)
                        .opacity(isVideoReady ? 0 : 1)
                }
                .offset(y: -30)
                
                VStack(spacing: 8) {
                    Text("KeyVox is ready...")
                        .font(.appFont(35, variant: .medium))
                        .foregroundColor(.white)
                    
                    VStack(spacing: -4) {
                        Text("Don’t worry, you’ll only have to")
                        Text("do this once per session.")
                    }
                    .font(.appFont(22, variant: .light))
                    .foregroundColor(Color(UIColor.systemGray))
                    .multilineTextAlignment(.center)
                }
                .offset(y: -5) // Nudge it up to stay closer to the video
                
                Spacer()
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
}

#Preview {
    ReturnToHostView()
        .environmentObject(AppServiceRegistry.shared.transcriptionManager)
}
