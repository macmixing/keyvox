import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

struct KeyboardDictationRenderedVariantKey: Hashable {
    let deterministicState: DictationDeterministicState
    let style: StyleRewriteStyle
}

enum KeyboardDictationChangeDisplaySource {
    case selectedPreference
    case activeInsertion
}

struct KeyboardDictationChangeSession {
    var sourceText: String
    var originalText: String
    let documentContextBeforeInput: String?
    let preparesAsDictationInsertion: Bool
    var currentText: String
    var currentStyle: StyleRewriteStyle
    var previousStyle: StyleRewriteStyle?
    var variants: [StyleRewriteStyle: String]
    var baselineDeterministicState: DictationDeterministicState?
    var currentDeterministicState: DictationDeterministicState?
    var deterministicVariants: [DictationDeterministicState: String]
    var renderedDeterministicVariants: [KeyboardDictationRenderedVariantKey: String]
    var capsBaselineIsUppercase: Bool
    var isCapsTransformApplied: Bool
    var uncappedCurrentText: String?
}
