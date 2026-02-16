import SwiftUI

// MARK: - Development Settings
// NOTE: This file contains the proprietary "Audio-Reactive Wave" visual identity
// referenced in LICENSE.md under Proprietary Assets and Branding.
private let isDevModeOversized = false // Set to false for normal size

struct RecordingOverlay: View {
    @ObservedObject var recorder: AudioRecorder
    var isTranscribing: Bool
    @ObservedObject var visibilityManager: OverlayVisibilityManager

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
                        signalState: recorder.liveInputSignalState
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
    }
}

struct BarView: View {
    var value: Double
    var index: Int
    var isTranscribing: Bool
    var signalState: LiveInputSignalState
    
    @State private var ripplePhase: Double = 0
    @State private var rippleTimer: Timer?
    
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
            .onAppear {
                startRippleAnimation()
            }
            .onDisappear {
                stopRippleAnimation()
            }
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
            // Quiet room noise: tiny "live" motion so users know the mic is hot.
            let quietWaveOffset = (ripplePhase * 0.45) + Double(index) * 0.65
            let quietWave = (sin(quietWaveOffset) * 0.5) + 0.5
            let quietLevel = min(max(value / 0.14, 0), 1)
            let subtleBaseLift: CGFloat = isDevModeOversized ? 3.2 : 1.2
            let subtleWaveRange: CGFloat = isDevModeOversized ? 6.8 : 2.6
            return flatHeight + (CGFloat(quietLevel) * subtleBaseLift) + (CGFloat(quietWave) * subtleWaveRange)
        }

        // Normal audio-reactive animation while recording and signal is present.
        let multipliers: [Double] = [0.4, 0.7, 1.0, 0.7, 0.4]
        let dynamicHeight = CGFloat(value * multipliers[index]) * maxHeight
        return max(minHeight, dynamicHeight)
    }
    
    private func startRippleAnimation() {
        // Prevent stacking multiple timers if the view re-appears
        if rippleTimer != nil { return }

        rippleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            // Timer tick updates are safe to do on the main run loop (scheduledTimer runs there by default)
            ripplePhase += 0.1
            if ripplePhase > .pi * 2 {
                ripplePhase = 0
            }
        }
    }

    private func stopRippleAnimation() {
        rippleTimer?.invalidate()
        rippleTimer = nil
    }
}
