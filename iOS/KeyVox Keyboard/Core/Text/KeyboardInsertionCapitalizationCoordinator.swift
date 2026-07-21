import KeyVoxTextComposition

enum KeyboardInsertionCapitalizationCoordinator {
    static func normalizeLeadingCapitalizationIfNeeded(
        text: String,
        documentContextBeforeInput: String?,
        shouldPreserveLeadingCapitalization: (String) -> Bool = { _ in false }
    ) -> String {
        let context = TextCompositionContext(precedingText: documentContextBeforeInput ?? "")
        return TextCompositionPolicy.normalizeLeadingCapitalizationIfNeeded(
            in: text,
            context: context,
            scope: .firstCharacter,
            preserveLeadingCapitalization: shouldPreserveLeadingCapitalization(text)
        )
    }
}
