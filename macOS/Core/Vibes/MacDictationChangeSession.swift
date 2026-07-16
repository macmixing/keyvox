import KeyVoxCore
import KeyVoxStyleRewrite

struct MacDictationChangeSession {
    var sourceText: String
    var originalText: String
    var currentText: String
    var currentStyle: StyleRewriteStyle
    var previousStyle: StyleRewriteStyle?
    var variants: [StyleRewriteStyle: String]
    let baselineDeterministicState: DictationDeterministicState
    var currentDeterministicState: DictationDeterministicState
    let deterministicVariants: [DictationDeterministicState: String]
    var renderedDeterministicVariants: [MacDictationRenderedVariantKey: String]
    let displaysAllCaps: Bool
}
