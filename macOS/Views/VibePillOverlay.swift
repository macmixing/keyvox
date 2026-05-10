import Combine
import SwiftUI

enum VibePillPresentationMetrics {
    static let hiddenScale: CGFloat = 0.12
    static let visibleScale: CGFloat = 1.0
    static let hiddenOpacity: Double = 0.0
    static let visibleOpacity: Double = 1.0
    static let entryResponse: Double = 0.24
    static let entryDamping: Double = 0.82
    static let exitDuration: TimeInterval = 0.28
    static let panelRemovalDelay: TimeInterval = 0.36
}

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

final class VibeCyclePillVisibilityController: ObservableObject {
    @Published private(set) var isVisible = false

    func present() {
        isVisible = true
    }

    func dismiss() {
        isVisible = false
    }
}

struct VibeCyclePillOverlay: View {
    let title: String
    let state: LogoBarView.VibePillState
    @ObservedObject var visibilityController: VibeCyclePillVisibilityController
    @State private var overlayScale: CGFloat = VibePillPresentationMetrics.hiddenScale
    @State private var overlayOpacity: Double = VibePillPresentationMetrics.hiddenOpacity

    var body: some View {
        LogoBarView(vibeTitle: title, state: state)
            .scaleEffect(overlayScale)
            .opacity(overlayOpacity)
            .onChange(of: visibilityController.isVisible) { isVisible in
                animateOverlayVisibility(isVisible)
            }
            .onAppear {
                applyHiddenState()
                DispatchQueue.main.async {
                    animateOverlayVisibility(visibilityController.isVisible)
                }
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

        withAnimation(.timingCurve(0.58, 0.0, 0.95, 0.32, duration: VibePillPresentationMetrics.exitDuration)) {
            applyHiddenState()
        }
    }

    private func applyHiddenState() {
        overlayScale = VibePillPresentationMetrics.hiddenScale
        overlayOpacity = VibePillPresentationMetrics.hiddenOpacity
    }
}
