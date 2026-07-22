import KeyVoxCore
import Testing
@testable import KeyVox_iOS

struct DictationDeterministicVariantResolverTests {
    @Test func sourceTextPrefersRenderedTargetTextWhenDeterministicVariantIsInline() {
        let resolver = DictationDeterministicVariantResolver()
        let sourceText = resolver.sourceText(
            for: DictationDeterministicState(
                paragraphsEnabled: false,
                listsEnabled: true
            ),
            deterministicText: "Tasks: 1. Alpha; 2. Beta",
            currentState: DictationDeterministicState(
                paragraphsEnabled: false,
                listsEnabled: false
            ),
            currentSourceText: "Tasks one Alpha two Beta",
            renderedTextForTargetState: "Tasks:\n\n1. Alpha\n2. Beta"
        )

        #expect(sourceText == "Tasks:\n\n1. Alpha\n2. Beta")
    }
}
