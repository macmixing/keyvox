public struct DictationDeterministicVariantResolver: Sendable {
    private let textFormatter: DictationDeterministicTextFormatter

    public init(textFormatter: DictationDeterministicTextFormatter = .init()) {
        self.textFormatter = textFormatter
    }

    public func targetState(
        from state: DictationDeterministicState,
        kind: DictationDeterministicControlKind
    ) -> DictationDeterministicState {
        switch kind {
        case .paragraphs:
            return DictationDeterministicState(
                paragraphsEnabled: !state.paragraphsEnabled,
                listsEnabled: state.listsEnabled
            )
        case .lists:
            return DictationDeterministicState(
                paragraphsEnabled: state.paragraphsEnabled,
                listsEnabled: !state.listsEnabled
            )
        }
    }

    public func sourceText(
        for targetState: DictationDeterministicState,
        deterministicText: String,
        currentState: DictationDeterministicState,
        currentSourceText: String,
        renderedTextForTargetState: String? = nil
    ) -> String {
        let targetText = renderedTextForTargetState ?? deterministicText
        guard targetState.paragraphsEnabled == false,
              currentState.listsEnabled,
              targetState.listsEnabled else {
            return targetText
        }

        return textFormatter.textWithParagraphBreaksCollapsedPreservingLists(currentSourceText)
    }
}
