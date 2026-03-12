import SwiftUI

// NOTE: This file contains the proprietary KeyVox logo system
// referenced in LICENSE.md under Proprietary Assets and Branding.
private let isDevModeOversized = false

struct LogoBarView: View {
    fileprivate enum Metrics {
        static let staticBaseSize: CGFloat = 44
        static let staticPhaseStep: Double = 0.1
        static let staticPhaseWrapPeriod: Double = .pi * 2

        static let overlayContentPadding: CGFloat = 8
        static let overlayShadowBleedPadding: CGFloat = 10

        static var overlayCircleSize: CGFloat {
            isDevModeOversized ? 300 : 50
        }

        static var overlayBarSpacing: CGFloat {
            isDevModeOversized ? 24 : 4
        }

        static var overlayBarWidth: CGFloat {
            isDevModeOversized ? 24 : 4
        }
    }

    private enum Presentation {
        case logo(size: CGFloat)
        case indicator(
            phase: AudioIndicatorPhase,
            timelineState: AudioIndicatorTimelineState,
            ringColor: Color
        )
    }

    private let presentation: Presentation

    @State private var ripplePhase: Double = 0
    @State private var rippleTimer: Timer?

    init(size: CGFloat = Metrics.staticBaseSize) {
        self.presentation = .logo(size: size)
    }

    init(
        phase: AudioIndicatorPhase,
        timelineState: AudioIndicatorTimelineState,
        ringColor: Color
    ) {
        self.presentation = .indicator(
            phase: phase,
            timelineState: timelineState,
            ringColor: ringColor
        )
    }

    static var panelSize: CGSize {
        let renderedSize = Metrics.overlayCircleSize + (Metrics.overlayContentPadding * 2)
        let paddedSize = renderedSize + (Metrics.overlayShadowBleedPadding * 2)
        return CGSize(width: paddedSize, height: paddedSize)
    }

    static var panelEdgeInset: CGFloat {
        Metrics.overlayShadowBleedPadding
    }

    var body: some View {
        switch presentation {
        case .logo(let size):
            StaticLogoView(size: size, ripplePhase: ripplePhase)
                .onAppear(perform: startRippleAnimation)
                .onDisappear(perform: stopRippleAnimation)
        case .indicator(let phase, let timelineState, let ringColor):
            IndicatorLogoView(
                phase: phase,
                timelineState: timelineState,
                ringColor: ringColor
            )
        }
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
                .stroke(Color.yellow.opacity(0.6), lineWidth: 2 * scale)
                .frame(width: size, height: size)
                .shadow(color: .yellow.opacity(0.3), radius: 4 * scale)

            HStack(spacing: 3 * scale) {
                ForEach(0..<5) { index in
                    StaticLogoSegmentView(index: index, ripplePhase: ripplePhase, scale: scale)
                }
            }
        }
    }
}

private struct IndicatorLogoView: View {
    let phase: AudioIndicatorPhase
    let timelineState: AudioIndicatorTimelineState
    let ringColor: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.8))
                .overlay(
                    Circle()
                        .stroke(ringColor.opacity(0.6), lineWidth: 2)
                )
                .shadow(radius: 10)
                .frame(width: LogoBarView.Metrics.overlayCircleSize, height: LogoBarView.Metrics.overlayCircleSize)

            HStack(spacing: LogoBarView.Metrics.overlayBarSpacing) {
                ForEach(0..<5) { index in
                    ReactiveIndicatorSegmentView(
                        index: index,
                        phase: phase,
                        timelineState: timelineState
                    )
                }
            }
        }
        .padding(LogoBarView.Metrics.overlayContentPadding)
        .padding(LogoBarView.Metrics.overlayShadowBleedPadding)
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
                    colors: [MacAppTheme.accent, MacAppTheme.accent.opacity(0.7)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.5), radius: 2 * scale, x: 0, y: 0)
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

private struct ReactiveIndicatorSegmentView: View {
    let index: Int
    let phase: AudioIndicatorPhase
    let timelineState: AudioIndicatorTimelineState

    var body: some View {
        RoundedRectangle(cornerRadius: 26)
            .fill(
                LinearGradient(
                    colors: [MacAppTheme.accent, MacAppTheme.accent.opacity(0.9)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .shadow(color: .yellow.opacity(0.9), radius: 4, x: 0, y: 0)
            .frame(width: LogoBarView.Metrics.overlayBarWidth, height: height)
            .animation(.spring(response: 0.3, dampingFraction: 0.9), value: timelineState.displayedLevel)
    }

    private var height: CGFloat {
        let minHeight: CGFloat = isDevModeOversized ? 18 : 6
        let flatHeight: CGFloat = isDevModeOversized ? 9 : 3
        let maxHeight: CGFloat = isDevModeOversized ? 170 : 30

        if phase == .processing {
            let waveOffset = timelineState.processingPhase + Double(index) * 0.8
            let rippleHeight = sin(waveOffset) * 0.5 + 0.5
            return flatHeight + (CGFloat(rippleHeight) * (isDevModeOversized ? 37 : 9))
        }

        guard phase == .listening else {
            return flatHeight
        }

        if timelineState.signalState == .inactive {
            return flatHeight
        }

        if timelineState.signalState == .lowActivity {
            let quietWaveOffset = timelineState.lowActivityPhase + Double(index) * 0.8
            let quietRipple = (sin(quietWaveOffset) * 0.5) + 0.5
            let wiggleOffset = (timelineState.lowActivityPhase * 0.9) + Double(index) * 1.35
            let ambientWiggle = (sin(wiggleOffset) * 0.5) + 0.5
            let quietLevel = min(max(timelineState.displayedLevel / 0.14, 0), 1)
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

        let multipliers: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]
        let dynamicHeight = timelineState.displayedLevel * multipliers[index] * maxHeight
        return max(minHeight, dynamicHeight)
    }
}
