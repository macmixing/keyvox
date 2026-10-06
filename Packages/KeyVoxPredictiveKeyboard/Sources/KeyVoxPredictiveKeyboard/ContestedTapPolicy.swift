/// Decides whether a contested tap was meant for a nearby letter, and which one.
///
/// Each nearby letter that leads to a real word scores its language-weighted
/// log-likelihood minus a touch penalty that grows with its distance from the touch. Before
/// a word starts, every key is a plausible intent, so only touches in the gap beside the
/// other key go to the best letter. Inside a word, the best letter beats shift, delete, 123,
/// and the globe outright; against space or return it must also beat the word ending here
/// by the boundary threshold.
public struct ContestedTapPolicy: Sendable, Equatable {
    public struct Parameters: Sendable, Equatable {
        /// Letters farther than this from a touch on space or return, in key pitches, are
        /// not considered.
        public var boundaryMaximumDistance: Double
        /// The same for shift, delete, 123, and the globe, which have no language check
        /// against the letter and so only yield to touches right at the letter's edge.
        public var controlMaximumDistance: Double
        /// Finger spread used for the touch penalty, in key pitches.
        public var touchStandardDeviation: Double
        public var languageWeight: Double
        public var boundaryThreshold: Double

        public init(
            boundaryMaximumDistance: Double,
            controlMaximumDistance: Double,
            touchStandardDeviation: Double,
            languageWeight: Double,
            boundaryThreshold: Double
        ) {
            self.boundaryMaximumDistance = boundaryMaximumDistance
            self.controlMaximumDistance = controlMaximumDistance
            self.touchStandardDeviation = touchStandardDeviation
            self.languageWeight = languageWeight
            self.boundaryThreshold = boundaryThreshold
        }

        /// The farthest a considered letter can be from any contested touch.
        public var maximumDistance: Double {
            max(boundaryMaximumDistance, controlMaximumDistance)
        }
    }

    public static let standardParameters = Parameters(
        boundaryMaximumDistance: 0.45,
        controlMaximumDistance: 0.25,
        touchStandardDeviation: 0.15,
        languageWeight: 0.5,
        boundaryThreshold: 0
    )

    public let parameters: Parameters

    public init(parameters: Parameters = ContestedTapPolicy.standardParameters) {
        self.parameters = parameters
    }

    /// The letter the tap was meant for, or nil to keep the other key.
    public func intendedLetter(for tap: ContestedTap) -> Character? {
        if tap.startsWord && tap.landedOnOtherKey { return nil }
        let spread = parameters.touchStandardDeviation
        let maximumDistance = tap.otherKey == .wordBoundary
            ? parameters.boundaryMaximumDistance
            : parameters.controlMaximumDistance
        let scored = tap.letters
            .filter { $0.distance <= maximumDistance }
            .map { letter in
                (
                    letter: letter.letter,
                    score: parameters.languageWeight * letter.continuationLogProbability
                        - letter.distance * letter.distance / (2 * spread * spread)
                )
            }
        guard let best = scored.max(by: { $0.score < $1.score }) else { return nil }
        guard tap.otherKey == .wordBoundary,
              tap.startsWord == false,
              let ending = tap.endingLogProbability else {
            return best.letter
        }
        return best.score - parameters.languageWeight * ending >= parameters.boundaryThreshold
            ? best.letter
            : nil
    }
}
