/// The categories the system emoji keyboard offers, in its order, by the identifiers the bundled
/// catalog uses, as recorded by watching it (Tools/AppleKeyboardBaseline, `EmojiOrderProbeTests`):
/// the emoji the user used most, which the host keeps, then the catalog's categories.
public enum EmojiKeyboardCategory: String, Sendable, CaseIterable {
    case frequentlyUsed = "frequently-used"
    case smileysPeople = "smileys-people"
    case animalsNature = "animals-nature"
    case foodDrink = "food-drink"
    case activity
    case travelPlaces = "travel-places"
    case objects
    case symbols
    case flags
}
