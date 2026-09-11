package org.keyvox.android.ime;

import java.util.Collections;
import java.util.LinkedHashMap;
import java.util.Map;
import org.keyvox.android.dictation.DictationResult;

/** Retains only the editor-local state needed to revise one untouched dictation. */
final class KeyboardDictationInsertion {
    final long editorGeneration;
    final String documentContextBeforeInput;
    final DictationResult.FormatState baselineState;
    final Map<DictationResult.FormatState, String> deterministicVariants;
    String currentText;
    DictationResult.FormatState currentState;

    KeyboardDictationInsertion(
            long editorGeneration,
            String documentContextBeforeInput,
            String currentText,
            DictationResult.FormatState baselineState,
            Map<DictationResult.FormatState, String> deterministicVariants) {
        this.editorGeneration = editorGeneration;
        this.documentContextBeforeInput = documentContextBeforeInput;
        this.currentText = currentText;
        this.baselineState = baselineState;
        this.currentState = baselineState;
        this.deterministicVariants = Collections.unmodifiableMap(
            new LinkedHashMap<>(deterministicVariants));
    }
}
