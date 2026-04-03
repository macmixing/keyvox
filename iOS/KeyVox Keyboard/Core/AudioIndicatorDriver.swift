import UIKit

enum AudioIndicatorPhase: Equatable {
    case idle
    case waiting
    case listening
    case processing
    case speaking
}

enum AudioIndicatorSignalState: Equatable {
    case inactive
    case lowActivity
    case active
}

struct AudioIndicatorSample: Equatable {
    let level: Float
    let signalState: AudioIndicatorSignalState
    let timestamp: TimeInterval
}

struct AudioIndicatorTimelineState: Equatable {
    let displayedLevel: CGFloat
    let signalState: AudioIndicatorSignalState
    let lowActivityPhase: Double
    let processingPhase: Double

    static let initial = AudioIndicatorTimelineState(
        displayedLevel: 0,
        signalState: .inactive,
        lowActivityPhase: 0,
        processingPhase: 0
    )
}

final class AudioIndicatorDriver {
    private enum Metrics {
        static let processingPhaseStep: Double = 0.1
        static let lowActivityPhaseStep: Double = 0.06
        static let phaseWrapPeriod: Double = .pi * 2
        static let meterPollInterval: CFTimeInterval = 1.0 / 30.0
        static let sampleFreshnessWindow: TimeInterval = 0.35
        static let smoothingRate: CGFloat = 16
    }

    var sampleProvider: (() -> AudioIndicatorSample?)?
    var onUpdate: ((AudioIndicatorTimelineState) -> Void)?

    var phase: AudioIndicatorPhase = .idle {
        didSet {
            guard oldValue != phase else { return }
            if phase != .listening {
                targetLevel = 0
                signalState = .inactive
            }
            publishState()
        }
    }

    private var displayLink: CADisplayLink?
    private var lastFrameTimestamp: CFTimeInterval?
    private var lastMeterPollTimestamp: CFTimeInterval?
    private var lowActivityPhase: Double = 0
    private var processingPhase: Double = 0
    private var displayedLevel: CGFloat = 0
    private var targetLevel: CGFloat = 0
    private var signalState: AudioIndicatorSignalState = .inactive

    func start() {
        guard displayLink == nil else { return }

        let displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLinkTick))
        displayLink.add(to: .main, forMode: .common)
        self.displayLink = displayLink
        publishState()
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastFrameTimestamp = nil
        lastMeterPollTimestamp = nil
    }

    @objc
    private func handleDisplayLinkTick(_ displayLink: CADisplayLink) {
        let previousTimestamp = lastFrameTimestamp ?? displayLink.timestamp
        let delta = min(max(displayLink.timestamp - previousTimestamp, 1.0 / 120.0), 1.0 / 20.0)
        lastFrameTimestamp = displayLink.timestamp

        processingPhase = wrappedPhase(processingPhase + Metrics.processingPhaseStep * delta * 60)
        lowActivityPhase = wrappedPhase(lowActivityPhase + Metrics.lowActivityPhaseStep * delta * 60)

        refreshSampleIfNeeded(at: displayLink.timestamp)

        let smoothing = CGFloat(min(delta * Double(Metrics.smoothingRate), 1))
        displayedLevel += (targetLevel - displayedLevel) * smoothing

        publishState()
    }

    private func refreshSampleIfNeeded(at timestamp: CFTimeInterval) {
        guard phase == .listening else {
            targetLevel = 0
            signalState = .inactive
            return
        }

        guard lastMeterPollTimestamp == nil || timestamp - (lastMeterPollTimestamp ?? 0) >= Metrics.meterPollInterval else {
            return
        }

        lastMeterPollTimestamp = timestamp

        guard let sample = sampleProvider?(),
              Date().timeIntervalSince1970 - sample.timestamp <= Metrics.sampleFreshnessWindow else {
            targetLevel = 0
            signalState = .inactive
            return
        }

        targetLevel = CGFloat(min(max(sample.level, 0), 1))
        signalState = sample.signalState
    }

    private func wrappedPhase(_ value: Double) -> Double {
        var wrapped = value
        while wrapped >= Metrics.phaseWrapPeriod {
            wrapped -= Metrics.phaseWrapPeriod
        }
        return wrapped
    }

    private func publishState() {
        onUpdate?(
            AudioIndicatorTimelineState(
                displayedLevel: displayedLevel,
                signalState: signalState,
                lowActivityPhase: lowActivityPhase,
                processingPhase: processingPhase
            )
        )
    }
}
