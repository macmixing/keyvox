import SwiftUI

// NOTE: This file contains the proprietary KeyVox logo implementation
// referenced in LICENSE.md under Proprietary Assets and Branding.
struct KeyVoxLogo: View {
    private static let phaseStep: Double = 0.1
    private static let phaseWrapPeriod: Double = .pi * 2

    @State private var ripplePhase: Double = 0
    @State private var rippleTimer: Timer?
    var size: CGFloat = 44
    
    var body: some View {
        let scale = size / 44.0
        
        ZStack {
            Circle()
                .stroke(Color.yellow.opacity(0.6), lineWidth: 2 * scale)
                .frame(width: size, height: size)
                .shadow(color: .yellow.opacity(0.3), radius: 4 * scale)
            
            HStack(spacing: 3 * scale) {
                ForEach(0..<5) { index in
                    MiniBarView(index: index, ripplePhase: ripplePhase, scale: scale)
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
        // Prevent stacking multiple timers if the view is recreated.
        if rippleTimer != nil { return }

        rippleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            ripplePhase += Self.phaseStep
            if ripplePhase >= Self.phaseWrapPeriod {
                // Keep sub-frame remainder to avoid visible jumps.
                ripplePhase -= Self.phaseWrapPeriod
            }
        }
    }

    private func stopRippleAnimation() {
        rippleTimer?.invalidate()
        rippleTimer = nil
    }
}

private struct MiniBarView: View {
    let index: Int
    let ripplePhase: Double
    let scale: CGFloat
    
    var body: some View {
        RoundedRectangle(cornerRadius: 2 * scale)
            .fill(
                LinearGradient(
                    colors: [.indigo, .indigo.opacity(0.7)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.5), radius: 2 * scale, x: 0, y: 0)
            .frame(width: 3.5 * scale, height: height)
    }
    
    var height: CGFloat {
        let waveOffset = ripplePhase + Double(index) * 0.8
        let rippleHeight = sin(waveOffset) * 0.5 + 0.5
        let baseHeight = 8.0 * scale
        let maxHeight = 10.0 * scale
        return baseHeight + (CGFloat(rippleHeight) * maxHeight)
    }
}
