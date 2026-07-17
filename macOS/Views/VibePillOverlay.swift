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

struct VibeCyclePillPresentation: Equatable {
    let isVisible: Bool
    let title: String
    let state: OverlayPillState
    let flipSequence: Int

    func visible() -> Self {
        Self(
            isVisible: true,
            title: title,
            state: state,
            flipSequence: flipSequence
        )
    }

    func hidden() -> Self {
        Self(
            isVisible: false,
            title: title,
            state: state,
            flipSequence: flipSequence
        )
    }

    func replacingFace(
        title: String,
        state: OverlayPillState,
        isVisible: Bool,
        forcesFlip: Bool = false
    ) -> Self {
        let didChangeFace = self.title != title || self.state != state
        let shouldFlip = didChangeFace && (self.isVisible || forcesFlip)
        return Self(
            isVisible: isVisible,
            title: title,
            state: state,
            flipSequence: shouldFlip ? flipSequence + 1 : flipSequence
        )
    }
}

final class VibeCyclePillVisibilityController: ObservableObject {
    @Published private(set) var presentation: VibeCyclePillPresentation

    init(
        title: String = "",
        state: OverlayPillState = .normal
    ) {
        presentation = VibeCyclePillPresentation(
            isVisible: false,
            title: title,
            state: state,
            flipSequence: 0
        )
    }

    var isVisible: Bool {
        presentation.isVisible
    }

    var title: String {
        presentation.title
    }

    var state: OverlayPillState {
        presentation.state
    }

    var flipSequence: Int {
        presentation.flipSequence
    }

    func present() {
        guard !presentation.isVisible else { return }
        presentation = presentation.visible()
    }

    func adoptVisiblePill(title: String, state: OverlayPillState) {
        presentation = VibeCyclePillPresentation(
            isVisible: true,
            title: title,
            state: state,
            flipSequence: presentation.flipSequence
        )
    }

    func present(title: String, state: OverlayPillState) {
        if presentation.isVisible {
            presentation = presentation.replacingFace(
                title: title,
                state: state,
                isVisible: true
            )
        } else {
            presentation = VibeCyclePillPresentation(
                isVisible: true,
                title: title,
                state: state,
                flipSequence: presentation.flipSequence
            )
        }
    }

    func continueVisibleCycle(title: String, state: OverlayPillState) {
        presentation = presentation.replacingFace(
            title: title,
            state: state,
            isVisible: true,
            forcesFlip: true
        )
    }

    func dismiss() {
        guard presentation.isVisible else { return }
        presentation = presentation.hidden()
    }
}

struct VibeCyclePillOverlay: View {
    @ObservedObject var visibilityController: VibeCyclePillVisibilityController
    private let adoptsVisiblePill: Bool
    private let onAdoptedAppear: (() -> Void)?
    @State private var overlayScale: CGFloat = VibePillPresentationMetrics.hiddenScale
    @State private var overlayOpacity: Double = VibePillPresentationMetrics.hiddenOpacity
    @State private var displayedTitle: String
    @State private var displayedState: OverlayPillState
    @State private var incomingTitle: String?
    @State private var incomingState: OverlayPillState = .normal
    @State private var outgoingFlipDegrees: Double = 0
    @State private var incomingFlipDegrees: Double = 92
    @State private var outgoingFaceOpacity: Double = 1
    @State private var incomingFaceOpacity: Double = 0
    @State private var activeFlipSequence = 0
    @State private var faceIdentity = 0

    init(
        visibilityController: VibeCyclePillVisibilityController,
        adoptsVisiblePill: Bool = false,
        onAdoptedAppear: (() -> Void)? = nil
    ) {
        self.visibilityController = visibilityController
        self.adoptsVisiblePill = adoptsVisiblePill
        self.onAdoptedAppear = onAdoptedAppear
        _displayedTitle = State(initialValue: visibilityController.title)
        _displayedState = State(initialValue: visibilityController.state)
    }

    var body: some View {
        ZStack {
            VibePillView(title: displayedTitle, state: displayedState)
                .id("outgoing-\(faceIdentity)-\(displayedTitle)-\(displayedState)")
                .opacity(outgoingFaceOpacity)
                .rotation3DEffect(
                    .degrees(outgoingFlipDegrees),
                    axis: (x: 1, y: 0, z: 0),
                    perspective: 0.82
                )

            if let incomingTitle {
                VibePillView(title: incomingTitle, state: incomingState)
                    .id("incoming-\(faceIdentity)-\(incomingTitle)-\(incomingState)")
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
            .onReceive(visibilityController.$presentation.dropFirst()) { presentation in
                handlePresentationChange(presentation)
            }
            .onAppear {
                displayedTitle = visibilityController.title
                displayedState = visibilityController.state
                if adoptsVisiblePill && visibilityController.isVisible {
                    overlayScale = VibePillPresentationMetrics.visibleScale
                    overlayOpacity = VibePillPresentationMetrics.visibleOpacity
                    DispatchQueue.main.async {
                        onAdoptedAppear?()
                    }
                    return
                }
                applyHiddenState()
                DispatchQueue.main.async {
                    animateOverlayVisibility(visibilityController.isVisible)
                }
            }
    }

    private func handlePresentationChange(_ presentation: VibeCyclePillPresentation) {
        if presentation.flipSequence != activeFlipSequence {
            animateForwardFlip(presentation: presentation)
        }
        animateOverlayVisibility(presentation.isVisible)
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

    private func animateForwardFlip(presentation: VibeCyclePillPresentation) {
        let sequence = presentation.flipSequence
        guard sequence != activeFlipSequence else { return }
        activeFlipSequence = sequence
        if let incomingTitle {
            displayedTitle = incomingTitle
            displayedState = incomingState
        }
        let nextTitle = presentation.title
        let nextState = presentation.state
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            faceIdentity += 1
            incomingTitle = nextTitle
            incomingState = nextState
            outgoingFlipDegrees = 0
            incomingFlipDegrees = 92
            outgoingFaceOpacity = 1
            incomingFaceOpacity = 0
        }

        DispatchQueue.main.async {
            guard activeFlipSequence == sequence else { return }
            withAnimation(.easeIn(duration: VibePillPresentationMetrics.flipHalfDuration)) {
                outgoingFlipDegrees = -92
                outgoingFaceOpacity = 0
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + VibePillPresentationMetrics.flipHalfDuration) {
            guard activeFlipSequence == sequence else { return }
            incomingFaceOpacity = 1
            withAnimation(.easeOut(duration: VibePillPresentationMetrics.flipHalfDuration)) {
                incomingFlipDegrees = 0
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + VibePillPresentationMetrics.flipHalfDuration) {
                guard activeFlipSequence == sequence else { return }
                displayedTitle = nextTitle
                displayedState = nextState
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
