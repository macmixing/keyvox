package org.keyvox.android.ime;

import android.app.Instrumentation;
import org.json.JSONArray;
import org.json.JSONObject;
import org.keyvox.android.app.AppSettingsStore;
import org.keyvox.android.dictation.DictationResult;

/** Stateful checks for persistent taps and reversible untouched-insertion changes. */
final class KeyboardDictationChangeInstrumentationChecks {
    private KeyboardDictationChangeInstrumentationChecks() {}

    static void run(Instrumentation runner) throws Exception {
        AppSettingsStore settings = new AppSettingsStore(runner.getTargetContext());
        boolean originalParagraphs = settings.autoParagraphsEnabled();
        boolean originalLists = settings.listFormattingEnabled();
        try {
            verifyPreferenceTaps(settings);
            verifyApplyRevertAndBlockedTap(settings);
            verifyParagraphChange(settings);
            verifyUnavailableAndIdenticalVariants(settings);
            verifyEditedAndMovedInsertions(settings);
            verifyEditorGenerationProtection(settings);
            verifyUnicodeReplacement(settings);
            verifyFailedReplacementRestoresInsertion(settings);
        } finally {
            settings.setAutoParagraphsEnabled(originalParagraphs);
            settings.setListFormattingEnabled(originalLists);
        }
    }

    private static void verifyPreferenceTaps(AppSettingsStore settings) {
        settings.setAutoParagraphsEnabled(false);
        settings.setListFormattingEnabled(false);
        EditorConnectionOwner editor = new EditorConnectionOwner();
        KeyboardDictationChangeController controller =
            new KeyboardDictationChangeController(editor, settings);

        check(controller.togglePreference(KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(settings.autoParagraphsEnabled());
        check(controller.togglePreference(KeyboardDictationChangeController.Kind.LISTS));
        check(settings.listFormattingEnabled());
    }

    private static void verifyApplyRevertAndBlockedTap(AppSettingsStore settings) throws Exception {
        settings.setAutoParagraphsEnabled(false);
        settings.setListFormattingEnabled(false);
        EditorBufferConnection fixture = new EditorBufferConnection("", 0, 0);
        EditorConnectionOwner editor = new EditorConnectionOwner();
        long generation = editor.attach(fixture.connection);
        KeyboardDictationInsertion insertion = editor.commitDictationResult(
            generation,
            1,
            result("v00", false, false, "v00", "v10", "v01", "v11")
        );
        KeyboardDictationChangeController controller =
            new KeyboardDictationChangeController(editor, settings);
        controller.recordInsertedDictation(insertion);

        check(controller.applyLongPressChange(KeyboardDictationChangeController.Kind.LISTS));
        check(fixture.text().equals("v01"));
        check(controller.displayedListFormattingEnabled());
        check(!settings.listFormattingEnabled());
        check(!controller.togglePreference(KeyboardDictationChangeController.Kind.LISTS));
        check(!settings.listFormattingEnabled());

        check(controller.applyLongPressChange(KeyboardDictationChangeController.Kind.LISTS));
        check(fixture.text().equals("v00"));
        check(!controller.displayedListFormattingEnabled());
    }

    private static void verifyParagraphChange(AppSettingsStore settings) throws Exception {
        settings.setAutoParagraphsEnabled(false);
        EditorBufferConnection fixture = new EditorBufferConnection("prefix", 6, 6);
        EditorConnectionOwner editor = new EditorConnectionOwner();
        long generation = editor.attach(fixture.connection);
        KeyboardDictationInsertion insertion = editor.commitDictationResult(
            generation,
            2,
            result("v00", false, false, "v00", "v10", "v01", "v11")
        );
        KeyboardDictationChangeController controller =
            new KeyboardDictationChangeController(editor, settings);
        controller.recordInsertedDictation(insertion);

        check(controller.applyLongPressChange(KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(fixture.text().equals("prefix v10"));
        check(controller.displayedAutoParagraphsEnabled());
        check(!settings.autoParagraphsEnabled());
    }

    private static void verifyUnavailableAndIdenticalVariants(AppSettingsStore settings) throws Exception {
        EditorBufferConnection missingFixture = new EditorBufferConnection("", 0, 0);
        EditorConnectionOwner missingEditor = new EditorConnectionOwner();
        long generation = missingEditor.attach(missingFixture.connection);
        KeyboardDictationInsertion missingInsertion = missingEditor.commitDictationResult(
            generation,
            3,
            result("v00", false, false, "v00", null, null, null)
        );
        KeyboardDictationChangeController missingController =
            new KeyboardDictationChangeController(missingEditor, settings);
        missingController.recordInsertedDictation(missingInsertion);
        check(!missingController.applyLongPressChange(
            KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(missingFixture.text().equals("v00"));

        EditorBufferConnection sameFixture = new EditorBufferConnection("", 0, 0);
        EditorConnectionOwner sameEditor = new EditorConnectionOwner();
        generation = sameEditor.attach(sameFixture.connection);
        KeyboardDictationInsertion sameInsertion = sameEditor.commitDictationResult(
            generation,
            4,
            result("v00", false, false, "v00", "v00", null, null)
        );
        KeyboardDictationChangeController sameController =
            new KeyboardDictationChangeController(sameEditor, settings);
        sameController.recordInsertedDictation(sameInsertion);
        check(!sameController.applyLongPressChange(
            KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(sameFixture.text().equals("v00"));
    }

    private static void verifyEditedAndMovedInsertions(AppSettingsStore settings) throws Exception {
        EditorBufferConnection editedFixture = new EditorBufferConnection("", 0, 0);
        EditorConnectionOwner editedEditor = new EditorConnectionOwner();
        long generation = editedEditor.attach(editedFixture.connection);
        KeyboardDictationInsertion editedInsertion = editedEditor.commitDictationResult(
            generation,
            5,
            result("v00", false, false, "v00", "v10", null, null)
        );
        KeyboardDictationChangeController editedController =
            new KeyboardDictationChangeController(editedEditor, settings);
        editedController.recordInsertedDictation(editedInsertion);
        editedFixture.connection.commitText("x", 1);
        check(!editedController.applyLongPressChange(
            KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(editedFixture.text().equals("v00x"));

        EditorBufferConnection movedFixture = new EditorBufferConnection("", 0, 0);
        EditorConnectionOwner movedEditor = new EditorConnectionOwner();
        generation = movedEditor.attach(movedFixture.connection);
        KeyboardDictationInsertion movedInsertion = movedEditor.commitDictationResult(
            generation,
            6,
            result("v00", false, false, "v00", "v10", null, null)
        );
        KeyboardDictationChangeController movedController =
            new KeyboardDictationChangeController(movedEditor, settings);
        movedController.recordInsertedDictation(movedInsertion);
        movedFixture.setSelection(0, 0);
        check(!movedController.applyLongPressChange(
            KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(movedFixture.text().equals("v00"));
    }

    private static void verifyEditorGenerationProtection(AppSettingsStore settings) throws Exception {
        EditorBufferConnection first = new EditorBufferConnection("", 0, 0);
        EditorBufferConnection second = new EditorBufferConnection("second", 6, 6);
        EditorConnectionOwner editor = new EditorConnectionOwner();
        long generation = editor.attach(first.connection);
        KeyboardDictationInsertion insertion = editor.commitDictationResult(
            generation,
            7,
            result("v00", false, false, "v00", "v10", null, null)
        );
        KeyboardDictationChangeController controller =
            new KeyboardDictationChangeController(editor, settings);
        controller.recordInsertedDictation(insertion);
        editor.attach(second.connection);

        check(!controller.applyLongPressChange(
            KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(first.text().equals("v00"));
        check(second.text().equals("second"));
    }

    private static void verifyUnicodeReplacement(AppSettingsStore settings) throws Exception {
        EditorBufferConnection fixture = new EditorBufferConnection("", 0, 0);
        EditorConnectionOwner editor = new EditorConnectionOwner();
        long generation = editor.attach(fixture.connection);
        KeyboardDictationInsertion insertion = editor.commitDictationResult(
            generation,
            8,
            result("🙂a", false, false, "🙂a", "🙂b", null, null)
        );
        KeyboardDictationChangeController controller =
            new KeyboardDictationChangeController(editor, settings);
        controller.recordInsertedDictation(insertion);

        check(controller.applyLongPressChange(KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(fixture.text().equals("🙂b"));
    }

    private static void verifyFailedReplacementRestoresInsertion(AppSettingsStore settings)
            throws Exception {
        EditorBufferConnection fixture = new EditorBufferConnection("", 0, 0);
        EditorConnectionOwner editor = new EditorConnectionOwner();
        long generation = editor.attach(fixture.connection);
        KeyboardDictationInsertion insertion = editor.commitDictationResult(
            generation,
            9,
            result("v00", false, false, "v00", "v10", null, null)
        );
        KeyboardDictationChangeController controller =
            new KeyboardDictationChangeController(editor, settings);
        controller.recordInsertedDictation(insertion);
        fixture.rejectNextCommit();

        check(!controller.applyLongPressChange(
            KeyboardDictationChangeController.Kind.PARAGRAPHS));
        check(fixture.text().equals("v00"));
    }

    private static DictationResult result(
            String selected,
            boolean baseParagraphs,
            boolean baseLists,
            String v00,
            String v10,
            String v01,
            String v11) throws Exception {
        JSONObject event = new JSONObject();
        event.put("text", selected);
        event.put("baseParagraphsEnabled", baseParagraphs);
        event.put("baseListsEnabled", baseLists);
        JSONArray variants = new JSONArray();
        addVariant(variants, false, false, v00);
        addVariant(variants, true, false, v10);
        addVariant(variants, false, true, v01);
        addVariant(variants, true, true, v11);
        event.put("deterministicVariants", variants);
        return DictationResult.from(event);
    }

    private static void addVariant(
            JSONArray variants,
            boolean paragraphs,
            boolean lists,
            String text) throws Exception {
        if (text == null) return;
        JSONObject variant = new JSONObject();
        variant.put("paragraphsEnabled", paragraphs);
        variant.put("listsEnabled", lists);
        variant.put("text", text);
        variants.put(variant);
    }

    private static void check(boolean condition) {
        if (!condition) throw new AssertionError("Keyboard dictation change invariant failed");
    }
}
