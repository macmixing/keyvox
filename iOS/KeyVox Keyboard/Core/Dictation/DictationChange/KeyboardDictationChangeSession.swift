import Foundation
import KeyVoxStyleRewrite

struct KeyboardDictationRenderedVariantKey: Hashable {
    let deterministicState: KeyboardDeterministicDictationState
    let style: StyleRewriteStyle
}

struct KeyboardDictationReplacement {
    let visibleText: String
    let postprocessedText: String
}

enum KeyboardDictationChangeDisplaySource {
    case selectedPreference
    case activeInsertion
}

struct KeyboardDictationChangeSession {
    var sourceText: String
    var originalText: String
    var captureID: String?
    var rawDictationText: String?
    var baseText: String?
    var artifactMetadata: [String: String]
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
