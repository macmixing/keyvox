import SwiftUI

// MARK: - Development Settings
// NOTE: This file contains the proprietary "Audio-Reactive Wave" visual identity
// referenced in LICENSE.md under Proprietary Assets and Branding.
private let isDevModeOversized = false // Set to false for normal size

struct RecordingOverlay: View {
    private static let phaseStep: Double = 0.1
    private static let quietPhaseStep: Double = 0.06 // Slower than processing, but still visibly alive in quiet rooms.
    private static let phaseWrapPeriod: Double = .pi * 2

    @ObservedObject var recorder: AudioRecorder
    var isTranscribing: Bool
    @ObservedObject var visibilityManager: OverlayVisibilityManager
    @State private var ripplePhase: Double = 0
    @State private var quietPhase: Double = 0
    @State private var rippleTimer: Timer?

    static var panelSize: CGSize {
        CGSize(
            width: isDevModeOversized ? 316 : 66,
            height: isDevModeOversized ? 316 : 66
        )
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Circle()
                        .stroke(Color.yellow.opacity(0.6), lineWidth: 2)
                )
                .shadow(radius: 10)
                .frame(width: isDevModeOversized ? 300 : 50, height: isDevModeOversized ? 300 : 50)
            
            HStack(spacing: isDevModeOversized ? 24 : 4) {
                ForEach(0..<5) { index in
                    BarView(
                        value: Double(recorder.audioLevel),
                        index: index,
                        isTranscribing: isTranscribing,
                        signalState: recorder.liveInputSignalState,
                        ripplePhase: ripplePhase,
                        quietPhase: quietPhase
                    )
                }
            }
        }
        .padding(8)
        .scaleEffect(visibilityManager.isVisible ? 1.0 : 0.3)
        .opacity(visibilityManager.isVisible ? 1.0 : 0.0)
        .animation(.spring(response: 0.16, dampingFraction: 0.88), value: visibilityManager.isVisible)
        .onChange(of: visibilityManager.shouldDismiss) { newValue in
            if newValue {
                withAnimation {
                    visibilityManager.isVisible = false
                }
            }
        }
        .onAppear {
            startRippleAnimation()
        }
        .onDisappear {
            stopRippleAnimation()
        }
    }

    private func startRippleAnimation() {
        // Prevent stacking multiple timers if the view re-appears.
        if rippleTimer != nil { return }

        rippleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Timer tick updates are safe on the main run loop.
            ripplePhase += Self.phaseStep
            quietPhase += Self.quietPhaseStep
            if ripplePhase >= Self.phaseWrapPeriod {
                // Subtract instead of hard-reset so we keep sub-frame remainder and avoid visible jumps.
                ripplePhase -= Self.phaseWrapPeriod
            }
            if quietPhase >= Self.phaseWrapPeriod {
                quietPhase -= Self.phaseWrapPeriod
            }
        }
    }

    private func stopRippleAnimation() {
        rippleTimer?.invalidate()
        rippleTimer = nil
    }
}

struct BarView: View {
    var value: Double
    var index: Int
    var isTranscribing: Bool
    var signalState: LiveInputSignalState
    var ripplePhase: Double
    var quietPhase: Double
    
    var body: some View {
        RoundedRectangle(cornerRadius: 26)
            .fill(
                LinearGradient(
                    colors: [Color.indigo, Color.indigo.opacity(0.9)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.9), radius: 4, x: 0, y: 0) // The "Glow"
            .frame(width: isDevModeOversized ? 24 : 4, height: height)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: value)
    }
    
    var height: CGFloat {
        let minHeight: CGFloat = isDevModeOversized ? 18 : 6
        let flatHeight: CGFloat = isDevModeOversized ? 9 : 3
        let maxHeight: CGFloat = isDevModeOversized ? 170 : 30

        if isTranscribing {
            // Ripple animation: subtle wave traveling left to right
            let waveOffset = ripplePhase + Double(index) * 0.8
            let rippleHeight = sin(waveOffset) * 0.5 + 0.5 // Range: 0.0 to 1.0
            // Thin baseline (3px) with ripple going up to 12px
            return flatHeight + (CGFloat(rippleHeight) * (isDevModeOversized ? 37 : 9))
        }

        if signalState == .dead {
            // Truly silent input: hard flatline.
            return flatHeight
        }

        if signalState == .quiet {
            // Ambient room-noise loop:
            // 1) slightly raised baseline, 2) gentle per-bar wiggle bed, 3) tiny right-to-left ripple on top.
            let quietWaveOffset = quietPhase + Double(index) * 0.8
            let quietRipple = (sin(quietWaveOffset) * 0.5) + 0.5
            let wiggleOffset = (quietPhase * 0.9) + Double(index) * 1.35
            let ambientWiggle = (sin(wiggleOffset) * 0.5) + 0.5
            let quietLevel = min(max(value / 0.14, 0), 1)
            let ambientBaseLift: CGFloat = isDevModeOversized ? 3.2 : 1.2
            let quietLevelLift: CGFloat = isDevModeOversized ? 2.3 : 0.8
            let ambientWiggleRange: CGFloat = isDevModeOversized ? 2.6 : 0.9
            let subtleRippleRange: CGFloat = isDevModeOversized ? 5.4 : 2.0
            return flatHeight
                + ambientBaseLift
                + (CGFloat(quietLevel) * quietLevelLift)
                + (CGFloat(ambientWiggle) * ambientWiggleRange)
                + (CGFloat(quietRipple) * subtleRippleRange)
        }

        // Normal audio-reactive animation while recording and signal is present.
        let multipliers: [Double] = [0.4, 0.7, 1.0, 0.7, 0.4]
        let dynamicHeight = CGFloat(value * multipliers[index]) * maxHeight
        return max(minHeight, dynamicHeight)
    }
}
