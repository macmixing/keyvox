/// How a theme draws the trail a swipe leaves across the letter keys: a stroke that follows the
/// finger with a round head, tapering and fading along the path the finger drew within a fixed
/// span of time behind it over a soft glow, then retracting into its head with a bloom once the
/// finger lifts. Colors are given for the light and dark appearances.
public struct KeyboardThemeSwipeTrail: Equatable, Sendable {
    /// A number that differs between the light and dark appearances.
    public struct Measure: Equatable, Sendable {
        public let light: Double
        public let dark: Double

        public init(light: Double, dark: Double) {
            self.light = light
            self.dark = dark
        }

        public static func same(_ value: Double) -> Measure {
            Measure(light: value, dark: value)
        }
    }

    /// One layer of the glow under the stroke.
    public struct Glow: Equatable, Sendable {
        /// The layer's width as a multiple of the stroke's.
        public let widthScale: Double
        /// The layer's opacity over `glowColor`.
        public let opacity: Measure

        public init(widthScale: Double, opacity: Measure) {
            self.widthScale = widthScale
            self.opacity = opacity
        }
    }

    /// The stroke.
    public let color: KeyboardThemeColor
    /// The dot at the finger.
    public let headColor: KeyboardThemeColor
    /// The color the glow's layers are drawn in at their own opacity.
    public let glowColor: KeyboardThemeColor
    /// The glow's layers, innermost first, nested under the stroke so its edge falls off softly.
    public let glows: [Glow]
    /// The stroke's width at the finger, in points.
    public let width: Measure
    /// The stroke's width at the end of its tail, as a share of `width`.
    public let tailWidthScale: Double
    /// How long a point of the path stays in the tail behind the finger, in seconds; the taper and
    /// fade follow the distance along the path within it, so they stay even where the finger
    /// lingers.
    public let tailDuration: Double
    /// How the tail fades: its opacity a share `t` of the way down it is `1 - t^exponent`.
    public let opacityFalloffExponent: Double
    /// How far each band of the tail runs under the next, in points, so no seam shows between them.
    public let bandOverlap: Double
    /// The head dot's diameter as a multiple of the stroke's width.
    public let headScale: Double
    /// How long the tail takes to retract into the head once the finger lifts, in seconds, keeping
    /// its taper.
    public let liftDuration: Double
    /// The retraction's timing curve, as the control points `x1, y1, x2, y2` of a cubic Bézier
    /// from (0, 0) to (1, 1).
    public let liftTiming: [Double]
    /// How far the head dot grows once the finger lifts, as a multiple of its size, at full opacity.
    public let bloomScale: Double
    /// How long the head dot takes to grow, in seconds.
    public let bloomDuration: Double
    /// How long the grown head dot takes to fade, in seconds.
    public let bloomFadeDuration: Double

    public init(
        color: KeyboardThemeColor,
        headColor: KeyboardThemeColor,
        glowColor: KeyboardThemeColor,
        glows: [Glow],
        width: Measure,
        tailWidthScale: Double,
        tailDuration: Double,
        opacityFalloffExponent: Double,
        bandOverlap: Double,
        headScale: Double,
        liftDuration: Double,
        liftTiming: [Double],
        bloomScale: Double,
        bloomDuration: Double,
        bloomFadeDuration: Double
    ) {
        self.color = color
        self.headColor = headColor
        self.glowColor = glowColor
        self.glows = glows
        self.width = width
        self.tailWidthScale = tailWidthScale
        self.tailDuration = tailDuration
        self.opacityFalloffExponent = opacityFalloffExponent
        self.bandOverlap = bandOverlap
        self.headScale = headScale
        self.liftDuration = liftDuration
        self.liftTiming = liftTiming
        self.bloomScale = bloomScale
        self.bloomDuration = bloomDuration
        self.bloomFadeDuration = bloomFadeDuration
    }
}

extension KeyboardThemeSwipeTrail {
    /// The glow the themes share unless one says otherwise: five nested layers at 1.3, 1.7, 2.2,
    /// 2.8, and 3.5 times the stroke's width at 10, 7, 5, 3, and 2 percent, falling off softly with
    /// no edge of its own.
    public static let standardGlows = [
        Glow(widthScale: 1.3, opacity: .same(0.10)),
        Glow(widthScale: 1.7, opacity: .same(0.07)),
        Glow(widthScale: 2.2, opacity: .same(0.05)),
        Glow(widthScale: 2.8, opacity: .same(0.03)),
        Glow(widthScale: 3.5, opacity: .same(0.02)),
    ]
    /// A tail tapering to a point at 15 percent of the stroke's width.
    public static let standardTailWidthScale = 0.15
    /// 0.55 seconds of the path behind the finger.
    public static let standardTailDuration = 0.55
    /// Opacity falling off as `1 - t^2`, so the front of the tail stays nearly solid.
    public static let standardOpacityFalloffExponent = 2.0
    /// Bands of the tail running half a point under the next.
    public static let standardBandOverlap = 0.5
    /// A head dot 1.15 times the stroke's width.
    public static let standardHeadScale = 1.15
    /// The tail retracting into the head over 0.22 seconds, easing in and out.
    public static let standardLiftDuration = 0.22
    public static let standardLiftTiming = [0.42, 0, 0.58, 1]
    /// The head dot growing to 1.8 times its size over 120 milliseconds at full opacity, then fading
    /// over 160 milliseconds.
    public static let standardBloomScale = 1.8
    public static let standardBloomDuration = 0.12
    public static let standardBloomFadeDuration = 0.16
}
