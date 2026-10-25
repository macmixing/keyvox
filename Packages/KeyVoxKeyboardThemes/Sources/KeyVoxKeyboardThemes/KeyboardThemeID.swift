/// The keyboard themes a user can choose, each saved by its raw value.
public enum KeyboardThemeID: String, CaseIterable, Sendable {
    /// KeyVox's own key colors, used unless the user picks another theme.
    case keyVox = "keyvox"
    /// Neutral key colors that follow each platform's system keyboard.
    case classic = "classic"

    /// The theme saved under `rawValue`, or the KeyVox theme when nothing valid is saved.
    public static func resolved(rawValue: String?) -> KeyboardThemeID {
        rawValue.flatMap(KeyboardThemeID.init(rawValue:)) ?? .keyVox
    }
}
