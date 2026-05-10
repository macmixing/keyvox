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
    static let flipHalfDuration: TimeInterval = 0.14
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
    @Published private(set) var title: String
    @Published private(set) var state: LogoBarView.VibePillState
    @Published private(set) var flipSequence = 0

    init(
        title: String = "",
        state: LogoBarView.VibePillState = .normal
    ) {
        self.title = title
        self.state = state
    }

    func present() {
        isVisible = true
    }

    func present(title: String, state: LogoBarView.VibePillState) {
        update(title: title, state: state)
        present()
    }

    func dismiss() {
        isVisible = false
    }

    private func update(title: String, state: LogoBarView.VibePillState) {
        guard self.title != title || self.state != state else { return }
        self.title = title
        self.state = state
        guard isVisible else { return }
        flipSequence += 1
    }
}

struct VibeCyclePillOverlay: View {
    @ObservedObject var visibilityController: VibeCyclePillVisibilityController
    @State private var overlayScale: CGFloat = VibePillPresentationMetrics.hiddenScale
    @State private var overlayOpacity: Double = VibePillPresentationMetrics.hiddenOpacity
    @State private var displayedTitle: String
    @State private var displayedState: LogoBarView.VibePillState
    @State private var incomingTitle: String?
    @State private var incomingState: LogoBarView.VibePillState = .normal
    @State private var outgoingFlipDegrees: Double = 0
    @State private var incomingFlipDegrees: Double = 92
    @State private var outgoingFaceOpacity: Double = 1
    @State private var incomingFaceOpacity: Double = 0
    @State private var activeFlipSequence = 0

    init(visibilityController: VibeCyclePillVisibilityController) {
        self.visibilityController = visibilityController
        _displayedTitle = State(initialValue: visibilityController.title)
        _displayedState = State(initialValue: visibilityController.state)
    }

    var body: some View {
        ZStack {
            LogoBarView(vibeTitle: displayedTitle, state: displayedState)
                .opacity(outgoingFaceOpacity)
                .rotation3DEffect(
                    .degrees(outgoingFlipDegrees),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.82
                )

            if let incomingTitle {
                LogoBarView(vibeTitle: incomingTitle, state: incomingState)
                    .opacity(incomingFaceOpacity)
                    .rotation3DEffect(
                        .degrees(incomingFlipDegrees),
                        axis: (x: 1, y: 0, z: 0),
                        perspective: 0.82
                    )
            }
        }
            .scaleEffect(overlayScale)
            .opacity(overlayOpacity)
            .onChange(of: visibilityController.isVisible) { isVisible in
                animateOverlayVisibility(isVisible)
            }
            .onChange(of: visibilityController.flipSequence) { sequence in
                animateForwardFlip(sequence: sequence)
            }
            .onAppear {
                displayedTitle = visibilityController.title
                displayedState = visibilityController.state
                applyHiddenState()
                DispatchQueue.main.async {
                    animateOverlayVisibility(visibilityController.isVisible)
                }
            }
    }

    private func animateOverlayVisibility(_ isVisible: Bool) {
        if isVisible {
            if overlayOpacity == VibePillPresentationMetrics.hiddenOpacity {
                displayedTitle = visibilityController.title
                displayedState = visibilityController.state
                resetFlipState()
            }
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
        resetFlipState()
    }

    private func animateForwardFlip(sequence: Int) {
        guard sequence != activeFlipSequence else { return }
        activeFlipSequence = sequence
        if let incomingTitle {
            displayedTitle = incomingTitle
            displayedState = incomingState
        }
        incomingTitle = visibilityController.title
        incomingState = visibilityController.state
        outgoingFlipDegrees = 0
        incomingFlipDegrees = 92
        outgoingFaceOpacity = 1
        incomingFaceOpacity = 0

        withAnimation(.easeIn(duration: VibePillPresentationMetrics.flipHalfDuration)) {
            outgoingFlipDegrees = -92
            outgoingFaceOpacity = 0
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + VibePillPresentationMetrics.flipHalfDuration) {
            guard activeFlipSequence == sequence else { return }
            incomingFaceOpacity = 1
            withAnimation(.easeOut(duration: VibePillPresentationMetrics.flipHalfDuration)) {
                incomingFlipDegrees = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + VibePillPresentationMetrics.flipHalfDuration) {
                guard activeFlipSequence == sequence else { return }
                displayedTitle = visibilityController.title
                displayedState = visibilityController.state
                resetFlipState()
            }
        }
    }

    private func resetFlipState() {
        incomingTitle = nil
        outgoingFlipDegrees = 0
        incomingFlipDegrees = 92
        outgoingFaceOpacity = 1
        incomingFaceOpacity = 0
    }
}
