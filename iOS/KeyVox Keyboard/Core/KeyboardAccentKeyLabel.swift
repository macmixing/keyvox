/// What the typing language's accent key shows: the character the letter layout draws on it, and
/// the mark or apostrophe it shows and types after the text before the cursor (`AccentKey`).
struct KeyboardAccentKeyLabel: Equatable {
    let character: String
    let mark: String
}

extension KeyboardKeyModel {
    /// The same key showing `label`'s mark when it is the accent key; any other key as it is.
    func showing(_ label: KeyboardAccentKeyLabel?) -> KeyboardKeyModel {
        guard let label, kind == .character(label.character) else { return self }
        var model = KeyboardKeyModel(kind: .character(label.mark), widthUnits: widthUnits)
        model.heldOffer = heldOffer
        return model
    }
}
