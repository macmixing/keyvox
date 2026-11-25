/// How a theme draws the trail a swipe leaves across the letter keys: a stroke that follows the
/// finger at full width and tapers as it fades behind it, over a wider, softer glow, with each
/// color given for the light and dark appearances.
public struct KeyboardThemeSwipeTrail: Equatable, Sendable {
    /// The stroke.
    public let color: KeyboardThemeColor
    /// The glow under the stroke; its alpha sets how strong the glow is.
    public let glowColor: KeyboardThemeColor
    /// The stroke's width at the finger, in points.
    public let width: Double
    /// The stroke's width where it has faded out, as a share of `width`.
    public let tailWidthScale: Double
    /// The glow's width as a multiple of the stroke's.
    public let glowWidthScale: Double
    /// How long a point of the trail lasts behind the finger, in seconds.
    public let fadeDuration: Double
    /// How long what is left of the trail takes to fade once the finger lifts, in seconds.
    public let liftFadeDuration: Double

    public init(
        color: KeyboardThemeColor,
        glowColor: KeyboardThemeColor,
        width: Double,
        tailWidthScale: Double,
        glowWidthScale: Double,
        fadeDuration: Double,
        liftFadeDuration: Double
    ) {
        self.color = color
        self.glowColor = glowColor
        self.width = width
        self.tailWidthScale = tailWidthScale
        self.glowWidthScale = glowWidthScale
        self.fadeDuration = fadeDuration
        self.liftFadeDuration = liftFadeDuration
    }
}
