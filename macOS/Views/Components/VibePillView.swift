import SwiftUI

struct VibePillView: View {
    let title: String
    let state: OverlayPillState

    @State private var isPulsing = false

    private var isProcessing: Bool {
        state == .processing
    }

    var body: some View {
        OverlayPillView(title: title, state: state) {
            ZStack {
                Image("vibes-logo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(Color.yellow.opacity(isProcessing ? (isPulsing ? 0.92 : 0.48) : 0))
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .scaleEffect(isProcessing && isPulsing ? 1.24 : 1.08)
                    .blur(radius: isProcessing ? 4 : 0)

                Image("vibes-logo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundStyle(.white)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
                    .scaleEffect(isProcessing && isPulsing ? 1.08 : 0.96)
            }
        }
        .onAppear(perform: updateProcessingAnimation)
        .onChange(of: state) { _ in
            updateProcessingAnimation()
        }
    }

    private func updateProcessingAnimation() {
        guard isProcessing else {
            isPulsing = false
            return
        }

        isPulsing = false
        withAnimation(.easeInOut(duration: 0.62).repeatForever(autoreverses: true)) {
            isPulsing = true
        }
    }
}
