import CoreGraphics
import KeyVoxEmoji

/// Where tapping a category in the emoji page's bar scrolls the grid, as on the system emoji
/// keyboard, recorded by watching it (Tools/AppleKeyboardBaseline, `EmojiFrequentlyUsedProbeTests`):
/// back to where the grid last was while the category showed at its leading edge, or the
/// category's start when the category already shows there or never has.
struct KeyboardEmojiCategoryMemory {
    private var offsets: [EmojiKeyboardCategory: CGFloat] = [:]

    /// Call as the grid scrolls, with the category at its leading edge.
    mutating func gridScrolled(to offset: CGFloat, showing category: EmojiKeyboardCategory) {
        offsets[category] = offset
    }

    /// Where tapping `category` scrolls the grid, given where its section starts and the category
    /// showing now.
    func offset(
        forTapping category: EmojiKeyboardCategory,
        sectionStart: CGFloat,
        showing current: EmojiKeyboardCategory?
    ) -> CGFloat {
        guard category != current, let remembered = offsets[category] else { return sectionStart }
        return remembered
    }
}
