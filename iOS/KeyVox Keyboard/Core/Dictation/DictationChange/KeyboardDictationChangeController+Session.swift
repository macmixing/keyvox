import Foundation
import KeyVoxCore
import KeyVoxStyleRewrite

extension KeyboardDictationChangeController {
    func recordInsertedDictation(
        _ insertion: KeyboardTextInsertionResult,
        artifactID: UUID?,
        styleIdentifier: String? = nil
    ) {
        displaySource = .selectedPreference

        guard let artifactID,
              let artifact = artifactStore.latestArtifact(matching: artifactID) else {
            let deliveredStyle = styleIdentifier.flatMap(StyleRewriteStyle.init(rawValue:)) ?? .none
            activeSession = KeyboardDictationChangeSession(
                artifactID: artifactID,
                hasLoadedArtifact: false,
                sourceText: insertion.sourceText,
                languageCode: nil,
                originalText: insertion.insertedText,
                documentContextBeforeInput: insertion.documentContextBeforeInput,
                preparesAsDictationInsertion: true,
                currentText: insertion.insertedText,
                currentStyle: deliveredStyle,
                previousStyle: nil,
                variants: [deliveredStyle: insertion.insertedText],
                baselineDeterministicState: nil,
                currentDeterministicState: nil,
                deterministicVariants: [:],
                renderedDeterministicVariants: [:],
                capsBaselineIsUppercase: false,
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

        var deterministicVariants: [DictationDeterministicState: String] = [:]
        for variant in artifact.deterministicVariants {
            let state = DictationDeterministicState(
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
            artifactID: artifactID,
            hasLoadedArtifact: true,
            sourceText: originalText,
            languageCode: artifact.languageCode,
            originalText: originalText,
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
    }

    func refreshActiveSessionFromArtifactIfAvailable() {
        guard let session = activeSession,
              session.hasLoadedArtifact == false,
              session.isCapsTransformApplied == false,
              let artifactID = session.artifactID,
              artifactStore.latestArtifact(matching: artifactID) != nil,
              activeInsertionMatchesCurrentText(session) else {
            return
        }

        recordInsertedDictation(
            KeyboardTextInsertionResult(
                sourceText: session.sourceText,
                insertedText: session.currentText,
                documentContextBeforeInput: session.documentContextBeforeInput
            ),
            artifactID: artifactID,
            styleIdentifier: session.currentStyle.styleIdentifier
        )
    }

    func invalidateActiveSession() {
        activeSession = nil
    }
}
