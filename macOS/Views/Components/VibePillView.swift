import SwiftUI

struct VibePillView: View {
    let title: String
    let state: OverlayPillState

    private var isProcessing: Bool {
        state == .processing
    }

    var body: some View {
        OverlayPillView(title: title, state: state) {
            OverlayPillProcessingIcon(
                isProcessing: isProcessing,
                foregroundColor: .white,
                idleScale: 0.96
            ) {
                Image("vibes-logo")
                    .resizable()
                    .renderingMode(.template)
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 20, height: 20)
            }
        }
    }
}
