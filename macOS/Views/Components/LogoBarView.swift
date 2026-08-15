import SwiftUI

// NOTE: This file contains the proprietary KeyVox logo system
// referenced in LICENSE.md under Proprietary Assets and Branding.
private let isDevModeOversized = false

struct LogoBarView: View {
    fileprivate enum Metrics {
        static let staticBaseSize: CGFloat = 44
        static let staticPhaseStep: Double = 0.1
        static let staticPhaseWrapPeriod: Double = .pi * 2

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
        let renderedSize = Metrics.overlayCircleSize + (OverlayPresentationMetrics.contentPadding * 2)
        let paddedSize = renderedSize + (OverlayPresentationMetrics.shadowBleedPadding * 2)
        return CGSize(width: paddedSize, height: paddedSize)
    }

    static var panelEdgeInset: CGFloat {
        OverlayPresentationMetrics.shadowBleedPadding
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
                .fill(Color.black)
                .overlay(
                    Circle()
                        .stroke(Color.yellow.opacity(0.6), lineWidth: 2 * scale)
                )
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

            indicatorBars
        }
        .padding(OverlayPresentationMetrics.contentPadding)
        .padding(OverlayPresentationMetrics.shadowBleedPadding)
    }

    @ViewBuilder
    private var indicatorBars: some View {
        if let timelineMode {
            TimelineView(.animation) { context in
                TimelineIndicatorBarsView(
                    mode: timelineMode,
                    phase: renderedTimelinePhase(at: context.date, mode: timelineMode),
                    displayedLevel: timelineState.displayedLevel
                )
            }
        } else {
            barStack()
        }
    }

    private var timelineMode: TimelineIndicatorBarsView.Mode? {
        if phase == .processing {
            return .processing
        }
        if phase == .listening {
            return .lowActivity
        }
        return nil
    }

    private func barStack() -> some View {
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

    private func renderedTimelinePhase(
        at date: Date,
        mode: TimelineIndicatorBarsView.Mode
    ) -> Double {
        let elapsed = max(date.timeIntervalSince1970 - timelineState.timestamp, 0)
        let phase: Double
        let rate: Double

        switch mode {
        case .lowActivity:
            phase = timelineState.lowActivityPhase
            rate = AudioIndicatorDriver.lowActivityPhaseRate
        case .processing:
            phase = timelineState.processingPhase
            rate = AudioIndicatorDriver.processingPhaseRate
        }

        return phase + (elapsed * rate)
    }
}

private struct TimelineIndicatorBarsView: View {
    enum Mode {
        case lowActivity
        case processing
    }

    let mode: Mode
    let phase: Double
    let displayedLevel: CGFloat

    var body: some View {
        Canvas { context, size in
            context.addFilter(.shadow(color: .yellow.opacity(0.9), radius: 4, x: 0, y: 0))

            let barWidth = LogoBarView.Metrics.overlayBarWidth
            let barSpacing = LogoBarView.Metrics.overlayBarSpacing
            let totalWidth = (barWidth * 5) + (barSpacing * 4)
            let firstBarX = (size.width - totalWidth) / 2

            for index in 0..<5 {
                let barHeight: CGFloat = switch mode {
                case .lowActivity:
                    max(
                        lowActivityBarHeight(
                            index: index,
                            phase: phase,
                            displayedLevel: displayedLevel
                        ),
                        listeningAudioDynamicHeight(
                            index: index,
                            displayedLevel: displayedLevel
                        )
                    )
                case .processing:
                    processingBarHeight(index: index, phase: phase)
                }
                let barRect = CGRect(
                    x: firstBarX + (CGFloat(index) * (barWidth + barSpacing)),
                    y: (size.height - barHeight) / 2,
                    width: barWidth,
                    height: barHeight
                )
                let barPath = Path(roundedRect: barRect, cornerRadius: 26)

                context.fill(
                    barPath,
                    with: .linearGradient(
                        Gradient(colors: [MacAppTheme.accent, MacAppTheme.accent.opacity(0.9)]),
                        startPoint: CGPoint(x: barRect.midX, y: barRect.maxY),
                        endPoint: CGPoint(x: barRect.midX, y: barRect.minY)
                    )
                )
            }
        }
        .frame(width: LogoBarView.Metrics.overlayCircleSize, height: LogoBarView.Metrics.overlayCircleSize)
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
        let flatHeight: CGFloat = isDevModeOversized ? 9 : 3

        guard phase == .listening else {
            return flatHeight
        }

        if timelineState.signalState == .inactive {
            return flatHeight
        }

        if timelineState.signalState == .lowActivity {
            return lowActivityBarHeight(
                index: index,
                phase: timelineState.lowActivityPhase,
                displayedLevel: timelineState.displayedLevel
            )
        }

        return listeningAudioBarHeight(
            index: index,
            displayedLevel: timelineState.displayedLevel
        )
    }
}

private func listeningAudioBarHeight(index: Int, displayedLevel: CGFloat) -> CGFloat {
    let minHeight: CGFloat = isDevModeOversized ? 18 : 6
    return max(
        minHeight,
        listeningAudioDynamicHeight(index: index, displayedLevel: displayedLevel)
    )
}

private func listeningAudioDynamicHeight(index: Int, displayedLevel: CGFloat) -> CGFloat {
    let maxHeight: CGFloat = isDevModeOversized ? 170 : 30
    let multipliers: [CGFloat] = [0.4, 0.7, 1.0, 0.7, 0.4]
    return displayedLevel * multipliers[index] * maxHeight
}

private func processingBarHeight(index: Int, phase: Double) -> CGFloat {
    let flatHeight: CGFloat = isDevModeOversized ? 9 : 3
    let waveOffset = phase + Double(index) * 0.8
    let rippleHeight = sin(waveOffset) * 0.5 + 0.5
    return flatHeight + (CGFloat(rippleHeight) * (isDevModeOversized ? 37 : 9))
}

private func lowActivityBarHeight(index: Int, phase: Double, displayedLevel: CGFloat) -> CGFloat {
    let flatHeight: CGFloat = isDevModeOversized ? 9 : 3
    let quietWaveOffset = phase + Double(index) * 0.8
    let quietRipple = (sin(quietWaveOffset) * 0.5) + 0.5
    let wiggleOffset = (phase * 0.9) + Double(index) * 1.35
    let ambientWiggle = (sin(wiggleOffset) * 0.5) + 0.5
    let quietLevel = min(max(displayedLevel / 0.14, 0), 1)
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
