import SwiftUI

// NOTE: This file contains the proprietary KeyVox logo system
// referenced in LICENSE.md under Proprietary Assets and Branding.

struct iOSLogoBarView: View {
    private enum Metrics {
        static let staticBaseSize: CGFloat = 44
        static let staticPhaseStep: Double = 0.1
        static let staticPhaseWrapPeriod: Double = .pi * 2
    }

    let size: CGFloat

    @State private var ripplePhase: Double = 0
    @State private var rippleTimer: Timer?

    init(size: CGFloat = Metrics.staticBaseSize) {
        self.size = size
    }

    var body: some View {
        StaticLogoView(size: size, ripplePhase: ripplePhase)
            .onAppear(perform: startRippleAnimation)
            .onDisappear(perform: stopRippleAnimation)
    }

    private func startRippleAnimation() {
        guard rippleTimer == nil else { return }

        rippleTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) { _ in
            ripplePhase += Metrics.staticPhaseStep
            if ripplePhase >= Metrics.staticPhaseWrapPeriod {
                ripplePhase -= Metrics.staticPhaseWrapPeriod
            }
        }
    }

    private func stopRippleAnimation() {
        rippleTimer?.invalidate()
        rippleTimer = nil
    }
}

private struct StaticLogoView: View {
    let size: CGFloat
    let ripplePhase: Double

    var body: some View {
        let scale = size / 44.0

        return ZStack {
            Circle()
                .fill(Color.black.opacity(0.82))
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.3), radius: 6 * scale)
            
            Circle()
                .stroke(Color.yellow.opacity(0.45), lineWidth: 2 * scale)
                .frame(width: size, height: size)
                .shadow(color: .yellow.opacity(0.35), radius: 6 * scale)
            
            Circle()
                .stroke(Color.yellow.opacity(0.6), lineWidth: 2 * scale)
                .frame(width: size, height: size)

            HStack(spacing: 3 * scale) {
                ForEach(0..<5) { index in
                    StaticLogoSegmentView(index: index, ripplePhase: ripplePhase, scale: scale)
                }
            }
        }
    }
}

private struct StaticLogoSegmentView: View {
    let index: Int
    let ripplePhase: Double
    let scale: CGFloat

    var body: some View {
        RoundedRectangle(cornerRadius: 2 * scale)
            .fill(
                LinearGradient(
                    colors: [Color.indigo, Color.indigo.opacity(0.9)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.75), radius: 2.2 * scale, x: 0, y: 0)
            .frame(width: 3.5 * scale, height: height)
    }

    private var height: CGFloat {
        let waveOffset = ripplePhase + Double(index) * 0.8
        let rippleHeight = sin(waveOffset) * 0.5 + 0.5
        let baseHeight = 8.0 * scale
        let maxHeight = 10.0 * scale
        return baseHeight + (CGFloat(rippleHeight) * maxHeight)
    }
}
