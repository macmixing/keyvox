import SwiftUI

struct RecordingOverlay: View {
    let recorder: AudioRecorder
    var isTranscribing: Bool
    @ObservedObject var visibilityManager: OverlayVisibilityManager
    @StateObject private var indicatorDriver = AudioIndicatorDriver()
    @State private var overlayScale: CGFloat = 0.12
    @State private var overlayOpacity: Double = 0
    @State private var popWorkItem: DispatchWorkItem?
    @State private var settleWorkItem: DispatchWorkItem?

    static var panelSize: CGSize {
        LogoBarView.panelSize
    }

    static var panelEdgeInset: CGFloat {
        LogoBarView.panelEdgeInset
    }

    var body: some View {
        LogoBarView(
            phase: indicatorPhase,
            timelineState: indicatorDriver.timelineState,
            ringColor: overlayRingColor
        )
        .scaleEffect(overlayScale)
        .opacity(overlayOpacity)
        .onChange(of: visibilityManager.isVisible) { isVisible in
            animateOverlayVisibility(isVisible)
        }
        .onChange(of: isTranscribing) { _ in
            indicatorDriver.setPhase(indicatorPhase)
        }
        .onChange(of: visibilityManager.shouldDismiss) { newValue in
            if newValue {
                visibilityManager.isVisible = false
            }
        }
        .onAppear {
            applyInitialOverlayVisibility()
            if visibilityManager.isVisible {
                configureIndicatorDriver()
            } else {
                stopIndicatorDriver()
            }
        }
        .onDisappear {
            popWorkItem?.cancel()
            popWorkItem = nil
            settleWorkItem?.cancel()
            settleWorkItem = nil
            stopIndicatorDriver()
        }
    }

    private var indicatorPhase: AudioIndicatorPhase {
        isTranscribing ? .processing : .listening
    }

    private func applyInitialOverlayVisibility() {
        overlayScale = visibilityManager.isVisible ? 1.0 : 0.12
        overlayOpacity = visibilityManager.isVisible ? 1.0 : 0.0
    }

    private func configureIndicatorDriver() {
        indicatorDriver.sampleProvider = { [recorder] in
            recorder.currentAudioIndicatorSample
        }
        indicatorDriver.setPhase(indicatorPhase)
        indicatorDriver.start()
    }

    private func stopIndicatorDriver() {
        indicatorDriver.stop()
        indicatorDriver.setPhase(.idle)
    }

    private func animateOverlayVisibility(_ isVisible: Bool) {
        popWorkItem?.cancel()
        popWorkItem = nil
        settleWorkItem?.cancel()
        settleWorkItem = nil

        if isVisible {
            configureIndicatorDriver()
            overlayOpacity = 1.0
            withAnimation(.easeOut(duration: 0.1)) {
                overlayScale = 0.92
            }

            let pop = DispatchWorkItem {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.5, blendDuration: 0.04)) {
                    overlayScale = 1.14
                }
            }
            popWorkItem = pop
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.08, execute: pop)

            let settle = DispatchWorkItem {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8, blendDuration: 0.06)) {
                    overlayScale = 1.0
                }
            }
            settleWorkItem = settle
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2, execute: settle)
            return
        }

        stopIndicatorDriver()
        withAnimation(.timingCurve(0.58, 0.0, 0.95, 0.32, duration: 0.18)) {
            overlayScale = 0.12
            overlayOpacity = 0.0
        }
    }

    private var overlayRingColor: Color {
        (visibilityManager.isHandsFreeLocked || visibilityManager.isHandsFreeModifierPreviewActive) ? .indigo : .yellow
    }
}
