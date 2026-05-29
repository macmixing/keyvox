import Foundation
import KeyVoxStyleRewrite

extension KeyboardDictationChangeController {
    func recordInsertedDictation(_ insertion: KeyboardTextInsertionResult) {
        displaySource = .selectedPreference

        guard let artifact = artifactStore.latestArtifact() else {
            activeSession = KeyboardDictationChangeSession(
                sourceText: insertion.sourceText,
                originalText: insertion.insertedText,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true,
                currentText: insertion.insertedText,
                currentStyle: .none,
                previousStyle: nil,
                variants: [.none: insertion.insertedText],
                currentDeterministicState: nil,
                deterministicVariants: [:],
                renderedDeterministicVariants: [:],
                isCapsTransformApplied: false,
                uncappedCurrentText: nil
            )
            return
        }

        let selectedStyle = artifact.selectedStyleIdentifier.flatMap(StyleRewriteStyle.init(rawValue:)) ?? .none
        let originalText = preparedText(
            artifact.baseText,
            documentContextBeforeInput: insertion.documentContextBeforeInput,
            preparesAsDictationInsertion: true
        )
        var variants: [StyleRewriteStyle: String] = [.none: originalText]
        variants[selectedStyle] = insertion.insertedText

        for variant in artifact.variants {
            guard let style = StyleRewriteStyle(rawValue: variant.styleIdentifier) else { continue }
            variants[style] = preparedText(
                variant.text,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true
            )
        }
        if let selectedUncappedText = artifact.selectedUncappedText {
            variants[selectedStyle] = preparedText(
                selectedUncappedText,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true
            )
        }

        var deterministicVariants: [KeyboardDeterministicDictationState: String] = [:]
        for variant in artifact.deterministicVariants {
            let state = KeyboardDeterministicDictationState(
                paragraphsEnabled: variant.paragraphsEnabled,
                listsEnabled: variant.listsEnabled
            )
            deterministicVariants[state] = preparedText(
                variant.text,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true
            )
        }
        let currentDeterministicState = artifactBaseDeterministicState(
            from: artifact,
            deterministicVariants: deterministicVariants
        ) ?? currentDeterministicState(
            matching: originalText,
            in: deterministicVariants
        )
        var renderedDeterministicVariants: [KeyboardDictationRenderedVariantKey: String] = [:]
        if let currentDeterministicState {
            renderedDeterministicVariants[KeyboardDictationRenderedVariantKey(
                deterministicState: currentDeterministicState,
                style: .none
            )] = originalText
            renderedDeterministicVariants[KeyboardDictationRenderedVariantKey(
                deterministicState: currentDeterministicState,
                style: selectedStyle
            )] = variants[selectedStyle] ?? insertion.insertedText
        }
        let initialCapsSourceText = initialCapsSourceText(
            insertedText: insertion.insertedText,
            uncappedText: variants[selectedStyle] ?? originalText
        )

        activeSession = KeyboardDictationChangeSession(
            sourceText: originalText,
            originalText: originalText,
            documentContextBeforeInput: insertion.documentContextBeforeInput,
            preparesAsDictationInsertion: true,
            currentText: insertion.insertedText,
            currentStyle: selectedStyle,
            previousStyle: nil,
            variants: variants,
            currentDeterministicState: currentDeterministicState,
            deterministicVariants: deterministicVariants,
            renderedDeterministicVariants: renderedDeterministicVariants,
            isCapsTransformApplied: initialCapsSourceText != nil,
            uncappedCurrentText: initialCapsSourceText
        )
    }

    func invalidateActiveSession() {
        activeSession = nil
    }
}
