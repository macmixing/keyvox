import SwiftUI

/// A translated line under a setup video that has English words in the picture.
struct SetupVideoCaptionView: View {
    private enum Metrics {
        static let fontSize: CGFloat = 15
        static let lineSpacing: CGFloat = 0
    }

    let text: String

    var body: some View {
        Text(text)
            .font(.appFont(Metrics.fontSize, variant: .light))
            .lineSpacing(Metrics.lineSpacing)
            .foregroundStyle(.white.opacity(0.72))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }
}
