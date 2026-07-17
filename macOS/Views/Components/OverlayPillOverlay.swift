import SwiftUI

struct OverlayPillOverlay<Content: View>: View {
    @ObservedObject var visibilityManager: OverlayVisibilityManager
    @ViewBuilder let content: () -> Content

    @State private var overlayScale: CGFloat = VibePillPresentationMetrics.hiddenScale
    @State private var overlayOpacity: Double = VibePillPresentationMetrics.hiddenOpacity

    var body: some View {
        content()
            .scaleEffect(overlayScale)
            .opacity(overlayOpacity)
            .onChange(of: visibilityManager.isVisible) { isVisible in
                animateOverlayVisibility(isVisible)
            }
            .onAppear {
                overlayScale = visibilityManager.isVisible
                    ? VibePillPresentationMetrics.visibleScale
                    : VibePillPresentationMetrics.hiddenScale
                overlayOpacity = visibilityManager.isVisible
                    ? VibePillPresentationMetrics.visibleOpacity
                    : VibePillPresentationMetrics.hiddenOpacity
            }
    }

    private func animateOverlayVisibility(_ isVisible: Bool) {
        if isVisible {
            overlayOpacity = VibePillPresentationMetrics.visibleOpacity
            withAnimation(.spring(
                response: VibePillPresentationMetrics.entryResponse,
                dampingFraction: VibePillPresentationMetrics.entryDamping
            )) {
                overlayScale = VibePillPresentationMetrics.visibleScale
            }
            return
        }

        withAnimation(.timingCurve(
            0.58,
            0.0,
            0.95,
            0.32,
            duration: VibePillPresentationMetrics.exitDuration
        )) {
            overlayScale = VibePillPresentationMetrics.hiddenScale
            overlayOpacity = VibePillPresentationMetrics.hiddenOpacity
        }
    }
}
