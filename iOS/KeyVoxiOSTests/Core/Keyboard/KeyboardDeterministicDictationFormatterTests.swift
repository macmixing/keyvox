import Testing
@testable import KeyVox_iOS

struct KeyboardDeterministicDictationFormatterTests {
    @Test func sourceTextPrefersRenderedTargetTextWhenDeterministicVariantIsInline() {
        let formatter = KeyboardDeterministicDictationFormatter()
        let sourceText = formatter.sourceText(
            for: KeyboardDeterministicDictationState(
                paragraphsEnabled: false,
                listsEnabled: true
            ),
            deterministicText: "Tasks: 1. Alpha; 2. Beta",
            currentState: KeyboardDeterministicDictationState(
                paragraphsEnabled: false,
                listsEnabled: false
            ),
            currentSourceText: "Tasks one Alpha two Beta",
            renderedTextForTargetState: "Tasks:\n\n1. Alpha\n2. Beta"
        )

        #expect(sourceText == "Tasks:\n\n1. Alpha\n2. Beta")
    }
}
