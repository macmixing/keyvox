extension EmojiCatalog {
    /// The catalog's sections keeping only the emoji and skin-tone versions `isDrawable` accepts,
    /// as the system draws them; the emoji the user used most are the host's to add.
    public func keyboardSections(isDrawable: (String) -> Bool) -> [EmojiKeyboardSection] {
        sections.map { section in
            EmojiKeyboardSection(category: section.category, emoji: section.emoji.compactMap { emoji in
                guard isDrawable(emoji.text) else { return nil }
                return Emoji(text: emoji.text, name: emoji.name, skinToneVariants: emoji.skinToneVariants.filter(isDrawable))
            })
        }
    }
}
