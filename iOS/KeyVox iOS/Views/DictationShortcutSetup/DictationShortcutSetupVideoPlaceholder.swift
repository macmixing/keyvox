import SwiftUI

struct DictationShortcutSetupVideoPlaceholder: View {
    let page: DictationShortcutSetupPage

    var body: some View {
        RoundedRectangle(cornerRadius: 28)
            .fill(Color.white.opacity(0.025))
            .overlay {
                RoundedRectangle(cornerRadius: 28)
                    .strokeBorder(
                        Color.white.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1, dash: [7, 7])
                    )
            }
            .overlay {
                Text("Video Placeholder — Page \(page.rawValue)")
                    .font(.appFont(16, variant: .light))
                    .foregroundStyle(.white.opacity(0.58))
            }
            .aspectRatio(1, contentMode: .fit)
            .accessibilityLabel("Video placeholder for page \(page.rawValue)")
    }
}
