import SwiftUI

struct VibePillOverlay: View {
    let title: String
    let state: LogoBarView.VibePillState
    @ObservedObject var visibilityManager: OverlayVisibilityManager
    @State private var overlayScale: CGFloat = 0.12
    @State private var overlayOpacity: Double = 0

    var body: some View {
        LogoBarView(vibeTitle: title, state: state)
            .scaleEffect(overlayScale)
            .opacity(overlayOpacity)
            .onChange(of: visibilityManager.isVisible) { isVisible in
                animateOverlayVisibility(isVisible)
            }
            .onAppear {
                overlayScale = visibilityManager.isVisible ? 1.0 : 0.12
                overlayOpacity = visibilityManager.isVisible ? 1.0 : 0.0
            }
    }

    private func animateOverlayVisibility(_ isVisible: Bool) {
        if isVisible {
            overlayOpacity = 1.0
            withAnimation(.spring(response: 0.24, dampingFraction: 0.82)) {
                overlayScale = 1.0
            }
            return
        }

        withAnimation(.timingCurve(0.58, 0.0, 0.95, 0.32, duration: 0.18)) {
            overlayScale = 0.12
            overlayOpacity = 0.0
        }
    }
}
