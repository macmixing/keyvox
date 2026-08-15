import Combine
import CoreGraphics
import Foundation

nonisolated enum AudioIndicatorPhase: Equatable {
    case idle
    case waiting
    case listening
    case processing
}

nonisolated enum AudioIndicatorSignalState: Equatable {
    case inactive
    case lowActivity
    case active
}

nonisolated struct AudioIndicatorSample: Equatable {
    let level: CGFloat
    let signalState: AudioIndicatorSignalState
    let timestamp: TimeInterval
}

nonisolated struct AudioIndicatorTimelineState: Equatable {
    let displayedLevel: CGFloat
    let signalState: AudioIndicatorSignalState
    let lowActivityPhase: Double
    let processingPhase: Double
    let timestamp: TimeInterval

    static let initial = AudioIndicatorTimelineState(
        displayedLevel: 0,
        signalState: .inactive,
        lowActivityPhase: 0,
        processingPhase: 0,
        timestamp: 0
    )
}

final class AudioIndicatorDriver: ObservableObject {
    static let animationFrameDuration: TimeInterval = 0.016
    static let lowActivityPhaseRate: Double = 3.6
    static let processingPhaseRate: Double = 6.0

    private enum Metrics {
        static let phaseWrapPeriod: Double = .pi * 2
        static let timerInterval: TimeInterval = AudioIndicatorDriver.animationFrameDuration
        static let meterPollInterval: TimeInterval = 1.0 / 30.0
        static let sampleFreshnessWindow: TimeInterval = 0.35
        static let attackSmoothingRate: CGFloat = 15
        static let decaySmoothingRate: CGFloat = 5
    }

    var sampleProvider: (() -> AudioIndicatorSample?)?

    @Published private(set) var timelineState: AudioIndicatorTimelineState = .initial

    private(set) var phase: AudioIndicatorPhase = .idle

    private var timer: Timer?
    private var lastTickTimestamp: TimeInterval?
    private var lastMeterPollTimestamp: TimeInterval?
    private var lowActivityPhase: Double = 0
    private var processingPhase: Double = 0
    private var displayedLevel: CGFloat = 0
    private var targetLevel: CGFloat = 0
    private var signalState: AudioIndicatorSignalState = .inactive

    deinit {
        timer?.invalidate()
    }

    func setPhase(_ phase: AudioIndicatorPhase) {
        assertMainThread()
        guard self.phase != phase else { return }
        self.phase = phase
        if phase != .listening {
            targetLevel = 0
            signalState = .inactive
        }
        publishTimelineState()
    }

    func start() {
        assertMainThread()
        guard timer == nil else { return }

        let timer = Timer(timeInterval: Metrics.timerInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            let sample = self.sampleProvider?()
            self.advance(to: Date().timeIntervalSince1970, sample: sample)
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
        publishTimelineState()
    }

    func stop() {
        assertMainThread()
        timer?.invalidate()
        timer = nil
        lastTickTimestamp = nil
        lastMeterPollTimestamp = nil
    }

    func advance(to timestamp: TimeInterval, sample: AudioIndicatorSample?) {
        assertMainThread()
        let previousTimestamp = lastTickTimestamp ?? timestamp
        let rawDelta = max(timestamp - previousTimestamp, 0)
        let delta = min(max(rawDelta, 1.0 / 120.0), 1.0 / 20.0)
        lastTickTimestamp = timestamp

        processingPhase = wrappedPhase(processingPhase + AudioIndicatorDriver.processingPhaseRate * delta)
        lowActivityPhase = wrappedPhase(lowActivityPhase + AudioIndicatorDriver.lowActivityPhaseRate * delta)

        refreshSampleIfNeeded(at: timestamp, sample: sample)

        let smoothingRate = targetLevel > displayedLevel
            ? Metrics.attackSmoothingRate
            : Metrics.decaySmoothingRate
        let smoothing = min(delta * smoothingRate, 1)
        displayedLevel += (targetLevel - displayedLevel) * smoothing

        publishTimelineState(at: timestamp)
    }

    private func refreshSampleIfNeeded(at timestamp: TimeInterval, sample: AudioIndicatorSample?) {
        guard phase == .listening else {
            targetLevel = 0
            signalState = .inactive
            return
        }

        guard lastMeterPollTimestamp == nil || timestamp - (lastMeterPollTimestamp ?? 0) >= Metrics.meterPollInterval else {
            return
        }

        lastMeterPollTimestamp = timestamp

        guard let sample,
              timestamp - sample.timestamp <= Metrics.sampleFreshnessWindow else {
            targetLevel = 0
            signalState = .inactive
            return
        }

        targetLevel = min(max(sample.level, 0), 1)
        signalState = sample.signalState
    }

    private func wrappedPhase(_ value: Double) -> Double {
        var wrapped = value
        while wrapped >= Metrics.phaseWrapPeriod {
            wrapped -= Metrics.phaseWrapPeriod
        }
        return wrapped
    }

    private func publishTimelineState(at timestamp: TimeInterval = Date().timeIntervalSince1970) {
        timelineState = AudioIndicatorTimelineState(
            displayedLevel: displayedLevel,
            signalState: signalState,
            lowActivityPhase: lowActivityPhase,
            processingPhase: processingPhase,
            timestamp: timestamp
        )
    }

    private func assertMainThread() {
        dispatchPrecondition(condition: .onQueue(.main))
    }
}

extension AudioIndicatorSignalState {
    init(liveInputSignalState: LiveInputSignalState) {
        switch liveInputSignalState {
        case .dead:
            self = .lowActivity
        case .quiet:
            self = .lowActivity
        case .active:
            self = .active
        }
    }
}

extension AudioRecorder {
    var currentAudioIndicatorSample: AudioIndicatorSample {
        AudioIndicatorSample(
            level: CGFloat(audioLevel),
            signalState: AudioIndicatorSignalState(liveInputSignalState: liveInputSignalState),
            timestamp: Date().timeIntervalSince1970
        )
    }
}
