/// A color in one appearance: either explicit values, or a color from the platform's system
/// palette.
public enum KeyboardThemeShade: Equatable, Sendable {
    case rgba(KeyboardThemeRGBA)
    case system(KeyboardThemeSystemColor)
}
