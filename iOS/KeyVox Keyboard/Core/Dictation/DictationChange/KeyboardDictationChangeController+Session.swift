import Foundation
import KeyVoxStyleRewrite

extension KeyboardDictationChangeController {
    func recordInsertedDictation(_ insertion: KeyboardTextInsertionResult) {
        displaySource = .selectedPreference

        guard let artifact = artifactStore.latestArtifact() else {
            activeSession = KeyboardDictationChangeSession(
                sourceText: insertion.sourceText,
                originalText: insertion.insertedText,
                captureID: nil,
                rawDictationText: nil,
                baseText: nil,
                artifactMetadata: [:],
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true,
                currentText: insertion.insertedText,
                currentStyle: .none,
                previousStyle: nil,
                variants: [.none: insertion.insertedText],
                baselineDeterministicState: nil,
                currentDeterministicState: nil,
                deterministicVariants: [:],
                renderedDeterministicVariants: [:],
                capsBaselineIsUppercase: false,
                isCapsTransformApplied: false,
                uncappedCurrentText: nil
            )
            ratingController.deactivate()
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
            captureID: artifact.id.uuidString,
            rawDictationText: artifact.rawText,
            baseText: artifact.baseText,
            artifactMetadata: artifact.metadata,
            documentContextBeforeInput: insertion.documentContextBeforeInput,
            preparesAsDictationInsertion: true,
            currentText: insertion.insertedText,
            currentStyle: selectedStyle,
            previousStyle: nil,
            variants: variants,
            baselineDeterministicState: currentDeterministicState,
            currentDeterministicState: currentDeterministicState,
            deterministicVariants: deterministicVariants,
            renderedDeterministicVariants: renderedDeterministicVariants,
            capsBaselineIsUppercase: initialCapsSourceText != nil,
            isCapsTransformApplied: false,
            uncappedCurrentText: initialCapsSourceText
        )
        if selectedStyle == .none {
            ratingController.deactivate()
        } else {
            let postprocessedText = artifact.variants.first {
                $0.styleIdentifier == selectedStyle.styleIdentifier
            }?.text ?? insertion.insertedText
            ratingController.activate(PersonalDictationCaptureVariantContext(
                captureID: artifact.id.uuidString,
                styleIdentifier: selectedStyle.styleIdentifier,
                sourceText: artifact.baseText,
                visibleText: insertion.insertedText,
                rawDictationText: artifact.rawText,
                baseText: artifact.baseText,
                postprocessedOutputText: postprocessedText,
                metadata: metadata(
                    style: selectedStyle,
                    processingMode: nil,
                    artifactMetadata: artifact.metadata
                )
            ))
        }
    }

    func invalidateActiveSession() {
        activeSession = nil
        ratingController.deactivate()
    }
}
