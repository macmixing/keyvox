/// How strongly a key's fill covers the keyboard backdrop behind it, from 0 (invisible) to 1
/// (solid), in each appearance.
public struct KeyboardThemeKeyOpacity: Equatable, Sendable {
    public let light: Double
    public let dark: Double

    public init(light: Double, dark: Double) {
        self.light = light
        self.dark = dark
    }
}
