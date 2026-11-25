import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

/// Decides which fingers on the letter keys are swiping rather than tapping, so fast tapping
/// never turns into a swipe (`~/KeyVoxLanguageData/swipe/tap-vs-swipe/README.md`, section 5).
///
/// A touch can become a swipe only when it lands eligible (the host's checks: a letter key on
/// the letter page of a field that takes words) with no other finger down, and loses that for
/// good the moment another finger lands before it qualifies. It qualifies on the first sample
/// whose straight-line distance from where it landed reaches the threshold, in key pitches,
/// while its mean speed since landing is at least `minimumSpeed`: one pitch at rest, or, when
/// it lands within `afterTapWindow` of the last tap that typed or deleted, from
/// `afterTapThreshold` down to the resting one over that window. A touch that never qualifies
/// is a tap.
public struct SwipeGate<TouchID: Hashable> {
    public struct Parameters: Sendable, Equatable {
        /// The distance a touch must travel at rest, in key pitches.
        public var restingThreshold: Double
        /// The distance a touch landing right after a tap must travel, in key pitches.
        public var afterTapThreshold: Double
        /// How long after a tap the threshold takes to fall back to the resting one, in seconds.
        public var afterTapWindow: TimeInterval
        /// The slowest mean speed since landing that still qualifies, in key pitches a second.
        public var minimumSpeed: Double
        /// Samples this soon after landing pass the speed check whatever their speed, in seconds,
        /// as the measurements the thresholds come from count them.
        public var instantInterval: TimeInterval

        public init(
            restingThreshold: Double,
            afterTapThreshold: Double,
            afterTapWindow: TimeInterval,
            minimumSpeed: Double,
            instantInterval: TimeInterval
        ) {
            self.restingThreshold = restingThreshold
            self.afterTapThreshold = afterTapThreshold
            self.afterTapWindow = afterTapWindow
            self.minimumSpeed = minimumSpeed
            self.instantInterval = instantInterval
        }
    }

    /// The gate the research recommends and measured on FUTO's swipes.
    public static var standardParameters: Parameters {
        Parameters(
            restingThreshold: 1,
            afterTapThreshold: 2,
            afterTapWindow: 0.4,
            minimumSpeed: 1.5,
            instantInterval: 0.005
        )
    }

    private struct Touch {
        let origin: CGPoint
        let landedAt: TimeInterval
        let pitch: Double
        let threshold: Double
        var canSwipe: Bool
        var isSwipe = false
    }

    public let parameters: Parameters
    private var touches: [TouchID: Touch] = [:]
    private var lastTapTime: TimeInterval?

    public init(parameters: Parameters = Self.standardParameters) {
        self.parameters = parameters
    }

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
            canSwipe: isEligible && othersDown == false && pitch > 0
        )
    }

    /// The finger moved to `location`. Returns true when this sample makes it a swipe.
    public mutating func touchMoved(_ id: TouchID, to location: CGPoint, time: TimeInterval) -> Bool {
        guard let touch = touches[id], touch.canSwipe, touch.isSwipe == false else { return false }
        let dx = Double(location.x - touch.origin.x)
        let dy = Double(location.y - touch.origin.y)
        let distance = (dx * dx + dy * dy).squareRoot() / touch.pitch
        let elapsed = time - touch.landedAt
        guard distance >= touch.threshold,
              elapsed <= parameters.instantInterval || distance / elapsed >= parameters.minimumSpeed else {
            return false
        }
        touches[id]?.isSwipe = true
        return true
    }

    /// The finger lifted or was cancelled.
    public mutating func touchEnded(_ id: TouchID) {
        touches[id] = nil
    }

    /// A tap typed or deleted at `time`, rollover included; a swipe's word does not count.
    public mutating func recordTap(at time: TimeInterval) {
        lastTapTime = time
    }

    public func isSwipe(_ id: TouchID) -> Bool {
        touches[id]?.isSwipe ?? false
    }

    /// Forgets every finger, as when the keys go away.
    public mutating func reset() {
        touches.removeAll()
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
