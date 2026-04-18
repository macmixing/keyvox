import SwiftUI

struct AppTintedScrollIndicator: View {
    private static let width: CGFloat = 3
    private static let minimumThumbHeight: CGFloat = 24
    private static let trailingTouchClearance: CGFloat = 12
    private static let overflowThreshold: CGFloat = 1

    let metrics: AppScrollMetrics
    let tint: Color

    var body: some View {
        GeometryReader { geometry in
            Capsule()
                .fill(tint.opacity(0.92))
                .frame(width: Self.width, height: thumbHeight(for: geometry.size.height))
                .offset(y: thumbOffset(for: geometry.size.height))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(width: Self.trailingTouchClearance)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func showsIndicator(trackHeight: CGFloat) -> Bool {
        metrics.contentHeight > metrics.visibleHeight + Self.overflowThreshold
            && trackHeight > Self.overflowThreshold
    }

    private var scrollableDistance: CGFloat {
        max(metrics.maximumVisibleMinY, Self.overflowThreshold)
    }

    private var scrollProgress: CGFloat {
        let rawProgress = metrics.visibleMinY / scrollableDistance
        return min(max(rawProgress, 0), 1)
    }

    private func thumbHeight(for trackHeight: CGFloat) -> CGFloat {
        guard showsIndicator(trackHeight: trackHeight) else { return 0 }
        let proportionalHeight = trackHeight * (metrics.visibleHeight / metrics.contentHeight)
        return min(trackHeight, max(Self.minimumThumbHeight, proportionalHeight))
    }

    private func thumbOffset(for trackHeight: CGFloat) -> CGFloat {
        let availableTrackDistance = max(trackHeight - thumbHeight(for: trackHeight), 0)
        return availableTrackDistance * scrollProgress
    }
}
