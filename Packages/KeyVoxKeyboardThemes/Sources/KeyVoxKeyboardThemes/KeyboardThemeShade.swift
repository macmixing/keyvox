/// A color in one appearance: either explicit values, or a color from the platform's system
/// palette, optionally at its own alpha in place of the system color's.
public enum KeyboardThemeShade: Equatable, Sendable {
    case rgba(KeyboardThemeRGBA)
    case system(KeyboardThemeSystemColor, alpha: Double? = nil)
}
