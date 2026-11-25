import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Decides which fingers on the letter keys are swiping rather than tapping, so fast tapping
/// never turns into a swipe (`~/KeyVoxLanguageData/swipe/tap-vs-swipe/README.md`, section 5, with
/// the hold and lift evidence measured in `KeyVoxTypingHarness swipe-gate`).
///
/// A touch can become a swipe only when it lands eligible (the host's checks: a letter key on the
/// letter page of a field that takes words) with no other finger down, and loses that for good the
/// moment another finger lands before it is decided. It meets the swipe threshold on the first
/// sample whose straight-line distance from where it landed reaches the threshold, in key
/// pitches, while its mean speed since landing is at least `minimumSpeed`: one pitch at rest, or,
/// when it lands within `afterTapWindow` of the last tap that typed or deleted, from
/// `afterTapThreshold` down to the resting one over that window.
///
/// Meeting the threshold is not yet a swipe, since a tap that rolls toward the next key meets it
/// just before lifting:
///
/// - Still down `holdAfterThreshold` later, the touch is a swipe.
/// - Lifting sooner, while moving at most `liftDecelerationRatio` of its fastest, as a finger
///   slowing into a swipe's last key does, it is a swipe.
/// - Lifting sooner at speed, it is undecided: another finger landing within `undecidedWindow` of
///   its lift makes it a tap, typed before that finger's key, as typing goes on; otherwise it is a
///   swipe.
///
/// A touch that never meets the threshold is a tap.
public struct SwipeGate<TouchID: Hashable> {
    public struct Parameters: Sendable, Equatable {
        /// The distance a touch must travel at rest, in key pitches.
        public var restingThreshold: Double
        /// The distance a touch landing right after a tap must travel, in key pitches.
        public var afterTapThreshold: Double
        /// How long after a tap the threshold takes to fall back to the resting one, in seconds.
        public var afterTapWindow: TimeInterval
        /// The slowest mean speed since landing that still meets the threshold, in key pitches a
        /// second.
        public var minimumSpeed: Double
        /// Samples this soon after landing pass the speed check whatever their speed, in seconds,
        /// as the measurements the thresholds come from count them.
        public var instantInterval: TimeInterval
        /// How long a touch must stay down after meeting the threshold to be a swipe, in seconds.
        public var holdAfterThreshold: TimeInterval
        /// The most of its fastest speed a touch lifting before the hold may still move at for its
        /// lift to make it a swipe.
        public var liftDecelerationRatio: Double
        /// The span speeds are measured over, in seconds.
        public var speedWindow: TimeInterval
        /// How long after an undecided touch lifts another finger's landing makes it a tap, in
        /// seconds.
        public var undecidedWindow: TimeInterval
        /// How far, in key pitches, a touch that may still swipe must travel from where it landed to
        /// count as traveling, as a host shows a swipe beginning: ten times the 2 px or so a tapping
        /// finger drifts (Buschek et al., CHI 2015).
        public var travelDistance: Double

        public init(
            restingThreshold: Double,
            afterTapThreshold: Double,
            afterTapWindow: TimeInterval,
            minimumSpeed: Double,
            instantInterval: TimeInterval,
            holdAfterThreshold: TimeInterval,
            liftDecelerationRatio: Double,
            speedWindow: TimeInterval,
            undecidedWindow: TimeInterval,
            travelDistance: Double
        ) {
            self.restingThreshold = restingThreshold
            self.afterTapThreshold = afterTapThreshold
            self.afterTapWindow = afterTapWindow
            self.minimumSpeed = minimumSpeed
            self.instantInterval = instantInterval
            self.holdAfterThreshold = holdAfterThreshold
            self.liftDecelerationRatio = liftDecelerationRatio
            self.speedWindow = speedWindow
            self.undecidedWindow = undecidedWindow
            self.travelDistance = travelDistance
        }
    }

    /// What a finger's lift made it.
    public enum Lift: Sendable, Equatable {
        case tap
        case swipe
        /// Decided by whether another finger lands within `undecidedWindow`
        /// (`settleUndecidedAsTaps`, `settleUndecided(at:)`).
        case undecided
    }

    /// The gate the research recommends and measured on swipe.futo.org's swipes, with the hold
    /// and lift evidence that keeps rolling taps taps.
    public static var standardParameters: Parameters {
        Parameters(
            restingThreshold: 1,
            afterTapThreshold: 2,
            afterTapWindow: 0.4,
            minimumSpeed: 1.5,
            instantInterval: 0.005,
            holdAfterThreshold: 0.025,
            liftDecelerationRatio: 0.5,
            speedWindow: 0.03,
            undecidedWindow: 0.5,
            travelDistance: 0.5
        )
    }

    private struct Touch {
        let origin: CGPoint
        let landedAt: TimeInterval
        let pitch: Double
        let threshold: Double
        var canSwipe: Bool
        var isSwipe = false
        /// When the touch first met the threshold.
        var metThresholdAt: TimeInterval?
        /// The samples within the last speed window, oldest first.
        var recent: [(time: TimeInterval, location: CGPoint)] = []
        /// The fastest speed over any speed window so far, in key pitches a second.
        var peakSpeed = 0.0
        /// The speed over the latest speed window, in key pitches a second.
        var latestSpeed = 0.0
        /// The farthest the touch has been from where it landed, in key pitches.
        var farthest = 0.0
    }

    public let parameters: Parameters
    private var touches: [TouchID: Touch] = [:]
    /// Undecided touches by when they lifted.
    private var undecided: [TouchID: TimeInterval] = [:]
    private var lastTapTime: TimeInterval?

    public init(parameters: Parameters = Self.standardParameters) {
        self.parameters = parameters
    }

    /// A finger is landing: every undecided touch is a tap. Call before `touchBegan` and before
    /// typing anything for the landing finger, and type the returned touches first.
    public mutating func settleUndecidedAsTaps() -> [TouchID] {
        defer { undecided.removeAll() }
        return undecided.sorted { $0.value < $1.value }.map(\.key)
    }

    /// The undecided touches no finger landed after within the window by `time`: swipes.
    public mutating func settleUndecided(at time: TimeInterval) -> [TouchID] {
        let settled = undecided.filter { time - $0.value >= parameters.undecidedWindow }
            .sorted { $0.value < $1.value }.map(\.key)
        settled.forEach { undecided[$0] = nil }
        return settled
    }

    /// Whether a lifted touch waits on what comes next.
    public var hasUndecidedTouches: Bool { undecided.isEmpty == false }

    /// A finger landed at `location`, in points, where a key pitch is `pitch` points.
    /// - Parameter isEligible: Whether the host lets this touch swipe at all.
    public mutating func touchBegan(
        _ id: TouchID,
        at location: CGPoint,
        time: TimeInterval,
        pitch: Double,
        isEligible: Bool
    ) {
        let othersDown = touches.isEmpty == false
        for key in touches.keys where touches[key]?.isSwipe == false {
            touches[key]?.canSwipe = false
        }
        touches[id] = Touch(
            origin: location,
            landedAt: time,
            pitch: pitch,
            threshold: threshold(landingAt: time),
            canSwipe: isEligible && othersDown == false && pitch > 0,
            recent: [(time, location)]
        )
    }

    /// The finger moved to `location`. Returns true when this sample makes it a swipe.
    public mutating func touchMoved(_ id: TouchID, to location: CGPoint, time: TimeInterval) -> Bool {
        guard var touch = touches[id], touch.canSwipe, touch.isSwipe == false else { return false }
        follow(&touch, to: location, time: time)
        if let metAt = touch.metThresholdAt, time - metAt >= parameters.holdAfterThreshold {
            touch.isSwipe = true
        }
        touches[id] = touch
        return touch.isSwipe
    }

    /// The finger lifted at `location`.
    public mutating func touchEnded(_ id: TouchID, at location: CGPoint, time: TimeInterval) -> Lift {
        guard var touch = touches.removeValue(forKey: id) else { return .tap }
        if touch.isSwipe { return .swipe }
        guard touch.canSwipe else { return .tap }
        follow(&touch, to: location, time: time)
        guard touch.metThresholdAt != nil else { return .tap }
        if touch.latestSpeed <= parameters.liftDecelerationRatio * touch.peakSpeed {
            return .swipe
        }
        undecided[id] = time
        return .undecided
    }

    /// The finger can no longer swipe, as when a held key's popup takes it, but it stays down, so a
    /// finger landing beside it still never swipes, until it lifts or is cancelled. A finger
    /// already swiping keeps swiping.
    public mutating func touchStopsSwiping(_ id: TouchID) {
        guard touches[id]?.isSwipe == false else { return }
        touches[id]?.canSwipe = false
    }

    /// The finger was cancelled; it is neither a tap nor a swipe.
    public mutating func touchCancelled(_ id: TouchID) {
        touches[id] = nil
        undecided[id] = nil
    }

    /// A tap typed or deleted at `time`, rollover included; a swipe's word does not count.
    public mutating func recordTap(at time: TimeInterval) {
        lastTapTime = time
    }

    public func isSwipe(_ id: TouchID) -> Bool {
        touches[id]?.isSwipe ?? false
    }

    /// Whether a touch that may still swipe, or is swiping, has traveled `travelDistance` from where
    /// it landed.
    public func isTraveling(_ id: TouchID) -> Bool {
        guard let touch = touches[id], touch.canSwipe else { return false }
        return touch.isSwipe || touch.farthest >= parameters.travelDistance
    }

    /// Forgets every finger, undecided ones included, as when the keys go away.
    public mutating func reset() {
        touches.removeAll()
        undecided.removeAll()
    }

    /// Takes a sample: whether it meets the threshold, and the speeds over the speed window.
    private func follow(_ touch: inout Touch, to location: CGPoint, time: TimeInterval) {
        let dx = Double(location.x - touch.origin.x)
        let dy = Double(location.y - touch.origin.y)
        let distance = (dx * dx + dy * dy).squareRoot() / touch.pitch
        touch.farthest = max(touch.farthest, distance)
        if touch.metThresholdAt == nil {
            let elapsed = time - touch.landedAt
            if distance >= touch.threshold,
               elapsed <= parameters.instantInterval || distance / elapsed >= parameters.minimumSpeed {
                touch.metThresholdAt = time
            }
        }
        touch.recent.append((time, location))
        touch.recent.removeAll { time - $0.time > parameters.speedWindow }
        if let oldest = touch.recent.first, touch.recent.count > 1, time > oldest.time {
            let dx = Double(location.x - oldest.location.x)
            let dy = Double(location.y - oldest.location.y)
            touch.latestSpeed = (dx * dx + dy * dy).squareRoot() / touch.pitch / (time - oldest.time)
            touch.peakSpeed = max(touch.peakSpeed, touch.latestSpeed)
        } else {
            touch.latestSpeed = 0
        }
    }

    /// The distance, in key pitches, a touch landing at `time` must travel.
    private func threshold(landingAt time: TimeInterval) -> Double {
        guard let lastTapTime else { return parameters.restingThreshold }
        let since = max(time - lastTapTime, 0)
        guard since < parameters.afterTapWindow else { return parameters.restingThreshold }
        return parameters.restingThreshold
            + (parameters.afterTapThreshold - parameters.restingThreshold) * (1 - since / parameters.afterTapWindow)
    }
}
