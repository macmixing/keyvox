import Foundation
import KeyVoxStyleRewrite

struct KeyboardDictationRenderedVariantKey: Hashable {
    let deterministicState: KeyboardDeterministicDictationState
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
    var currentDeterministicState: KeyboardDeterministicDictationState?
    var deterministicVariants: [KeyboardDeterministicDictationState: String]
    var renderedDeterministicVariants: [KeyboardDictationRenderedVariantKey: String]
    var capsBaselineIsUppercase: Bool
    var isCapsTransformApplied: Bool
    var uncappedCurrentText: String?
}
