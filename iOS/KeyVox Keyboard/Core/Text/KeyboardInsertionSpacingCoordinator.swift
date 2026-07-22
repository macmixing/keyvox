import KeyVoxTextComposition

enum KeyboardInsertionSpacingCoordinator {
    static func applySmartLeadingSeparatorIfNeeded(
        to text: String,
        documentContextBeforeInput: String?
    ) -> String {
        TextCompositionPolicy.applySmartLeadingSeparatorIfNeeded(
            to: text,
            context: TextCompositionContext(precedingText: documentContextBeforeInput ?? "")
        )
    }
}
