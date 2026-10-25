/// The keyboard themes a user can choose, each saved by its raw value.
public enum KeyboardThemeID: String, CaseIterable, Sendable {
    /// KeyVox's own key colors, used unless the user picks another theme.
    case `default` = "default"
    /// Neutral key colors that follow the system keyboard's light and dark grays.
    case classic = "classic"

    /// The theme saved under `rawValue`, or the default theme when nothing valid is saved.
    public static func resolved(rawValue: String?) -> KeyboardThemeID {
        rawValue.flatMap(KeyboardThemeID.init(rawValue:)) ?? .default
    }
}
