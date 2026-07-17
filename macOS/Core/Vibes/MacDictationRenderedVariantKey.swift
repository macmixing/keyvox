import KeyVoxCore
import KeyVoxStyleRewrite

struct MacDictationRenderedVariantKey: Hashable {
    let deterministicState: DictationDeterministicState
    let style: StyleRewriteStyle
}
