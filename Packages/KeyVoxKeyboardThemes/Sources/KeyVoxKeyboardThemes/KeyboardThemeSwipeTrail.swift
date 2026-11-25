/// How a theme draws the trail a swipe leaves across the letter keys: a stroke that follows the
/// finger with a round head, tapering and fading along a fixed span of time behind it over a
/// soft glow, then retracting into its head with a bloom once the finger lifts. Colors are given
/// for the light and dark appearances.
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
    /// How long a point of the path stays in the tail behind the finger, in seconds.
    public let tailDuration: Double
    /// How the tail fades: its opacity at a share `t` of the way down it is `1 - t^exponent`.
    public let opacityFalloffExponent: Double
    /// The head dot's diameter as a multiple of the stroke's width.
    public let headScale: Double
    /// How long the tail takes to retract into the head once the finger lifts, in seconds, easing
    /// out.
    public let liftDuration: Double
    /// How far the head dot grows once the finger lifts, as a multiple of its size.
    public let bloomScale: Double
    /// How long the head dot takes to grow, in seconds.
    public let bloomDuration: Double

    public init(
        color: KeyboardThemeColor,
        headColor: KeyboardThemeColor,
        glowColor: KeyboardThemeColor,
        glows: [Glow],
        width: Measure,
        tailWidthScale: Double,
        tailDuration: Double,
        opacityFalloffExponent: Double,
        headScale: Double,
        liftDuration: Double,
        bloomScale: Double,
        bloomDuration: Double
    ) {
        self.color = color
        self.headColor = headColor
        self.glowColor = glowColor
        self.glows = glows
        self.width = width
        self.tailWidthScale = tailWidthScale
        self.tailDuration = tailDuration
        self.opacityFalloffExponent = opacityFalloffExponent
        self.headScale = headScale
        self.liftDuration = liftDuration
        self.bloomScale = bloomScale
        self.bloomDuration = bloomDuration
    }
}

extension KeyboardThemeSwipeTrail {
    /// The glow the themes share unless one says otherwise: three nested layers at 1.5, 2.2, and 3
    /// times the stroke's width at 14, 8, and 4 percent.
    public static let standardGlows = [
        Glow(widthScale: 1.5, opacity: .same(0.14)),
        Glow(widthScale: 2.2, opacity: .same(0.08)),
        Glow(widthScale: 3, opacity: .same(0.04)),
    ]
    /// A tail tapering to a point at 15 percent of the stroke's width.
    public static let standardTailWidthScale = 0.15
    /// 0.55 seconds of the path behind the finger.
    public static let standardTailDuration = 0.55
    /// Opacity falling off as `1 - t^2`, so the front of the tail stays nearly solid.
    public static let standardOpacityFalloffExponent = 2.0
    /// A head dot 1.15 times the stroke's width.
    public static let standardHeadScale = 1.15
    /// The tail retracting into the head over 0.28 seconds.
    public static let standardLiftDuration = 0.28
    /// The head dot growing to 1.4 times its size over 120 milliseconds.
    public static let standardBloomScale = 1.4
    public static let standardBloomDuration = 0.12
}
