package org.keyvox.android.ime;

import org.keyvox.android.app.AppSettingsStore;
import org.keyvox.android.dictation.DictationResult;

/** Applies persistent setting taps and reversible changes to the latest untouched insertion. */
final class KeyboardDictationChangeController {
    enum Kind { PARAGRAPHS, LISTS }

    private final EditorConnectionOwner editor;
    private final AppSettingsStore settings;
    private KeyboardDictationInsertion activeInsertion;

    KeyboardDictationChangeController(EditorConnectionOwner editor, AppSettingsStore settings) {
        this.editor = editor;
        this.settings = settings;
    }

    void recordInsertedDictation(KeyboardDictationInsertion insertion) {
        activeInsertion = insertion == null || insertion.currentText.isEmpty() ? null : insertion;
    }

    boolean togglePreference(Kind kind) {
        if (hasActiveTransform(kind)) return false;
        switch (kind) {
            case PARAGRAPHS:
                settings.setAutoParagraphsEnabled(!settings.autoParagraphsEnabled());
                return true;
            case LISTS:
                settings.setListFormattingEnabled(!settings.listFormattingEnabled());
                return true;
            default:
                return false;
        }
    }

    boolean applyLongPressChange(Kind kind) {
        KeyboardDictationInsertion insertion = activeInsertion;
        if (insertion == null || insertion.currentState == null) return false;
        if (!editor.currentTextMatchesUntouchedInsertion(insertion)) {
            activeInsertion = null;
            return false;
        }

        DictationResult.FormatState targetState = kind == Kind.PARAGRAPHS
            ? insertion.currentState.togglingParagraphs()
            : insertion.currentState.togglingLists();
        String replacementText = insertion.deterministicVariants.get(targetState);
        if (replacementText == null || replacementText.equals(insertion.currentText)) return false;
        if (!editor.replaceUntouchedInsertion(insertion, replacementText)) {
            activeInsertion = null;
            return false;
        }

        insertion.currentText = replacementText;
        insertion.currentState = targetState;
        return true;
    }

    boolean displayedAutoParagraphsEnabled() {
        return hasActiveTransform(Kind.PARAGRAPHS)
            ? activeInsertion.currentState.paragraphsEnabled
            : settings.autoParagraphsEnabled();
    }

    boolean displayedListFormattingEnabled() {
        return hasActiveTransform(Kind.LISTS)
            ? activeInsertion.currentState.listsEnabled
            : settings.listFormattingEnabled();
    }

    private boolean hasActiveTransform(Kind kind) {
        KeyboardDictationInsertion insertion = activeInsertion;
        if (insertion == null || insertion.baselineState == null || insertion.currentState == null
                || !editor.currentTextMatchesUntouchedInsertion(insertion)) {
            return false;
        }
        switch (kind) {
            case PARAGRAPHS:
                return insertion.currentState.paragraphsEnabled
                    != insertion.baselineState.paragraphsEnabled;
            case LISTS:
                return insertion.currentState.listsEnabled
                    != insertion.baselineState.listsEnabled;
            default:
                return false;
        }
    }
}
