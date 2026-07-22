import SwiftUI

struct OverlayPillView<Icon: View>: View {
    let title: String
    let state: OverlayPillState
    let contentSpacing: CGFloat
    @ViewBuilder let icon: () -> Icon

    @State private var completionProgress = 0.0

    init(
        title: String,
        state: OverlayPillState,
        contentSpacing: CGFloat = OverlayPillMetrics.contentSpacing,
        @ViewBuilder icon: @escaping () -> Icon
    ) {
        self.title = title
        self.state = state
        self.contentSpacing = contentSpacing
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: contentSpacing) {
            icon()
                .frame(width: 30, height: 30)

            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(width: OverlayPillMetrics.width, height: OverlayPillMetrics.height)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.82))
                .overlay(pillStroke)
                .shadow(color: MacAppTheme.accent.opacity(0.32), radius: 10)
        )
        .padding(OverlayPresentationMetrics.contentPadding)
        .padding(OverlayPresentationMetrics.shadowBleedPadding)
        .onAppear(perform: updateCompletionAnimation)
        .onChange(of: state) { _ in
            updateCompletionAnimation()
        }
    }

    @ViewBuilder
    private var pillStroke: some View {
        switch state {
        case .completed:
            OverlayPillCompletionStroke(progress: 1)
                .stroke(MacAppTheme.accent.opacity(0.68), lineWidth: 2)
                .overlay(
                    OverlayPillCompletionStroke(progress: completionProgress)
                        .stroke(
                            Color.yellow.opacity(0.92),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                )
        case .normal, .processing:
            Capsule()
                .stroke(MacAppTheme.accent.opacity(0.68), lineWidth: 2)
        }
    }

    private func updateCompletionAnimation() {
        guard state == .completed else {
            completionProgress = 0
            return
        }

        completionProgress = 0
        withAnimation(.easeOut(duration: 0.46)) {
            completionProgress = 1
        }
    }
}
