package org.keyvox.android.dictation;

/** Installed checks for exact dictation insertion and extra-line-break detection. */
public final class DictationInsertionResultInstrumentationChecks {
    private DictationInsertionResultInstrumentationChecks() {}

    public static void run() {
        String[] existingValues = {"", "a", "\n", "a\nb"};
        String[] insertedValues = {"x", "x\ny", "x\n"};
        for (String before : existingValues) {
            for (String inserted : insertedValues) {
                for (int cursor = 0; cursor <= before.length(); cursor++) {
                    String expected = before.substring(0, cursor)
                        + inserted
                        + before.substring(cursor);
                    DictationInsertionResult exact = DictationInsertionResult.evaluate(
                        before,
                        inserted,
                        cursor,
                        cursor,
                        expected
                    );
                    check(exact.inserted());
                    check(!exact.needsCorrection());

                    int insertionEnd = cursor + inserted.length();
                    String withExtraLineBreak = expected.substring(0, insertionEnd)
                        + "\n"
                        + expected.substring(insertionEnd);
                    DictationInsertionResult corrected = DictationInsertionResult.evaluate(
                        before,
                        inserted,
                        -1,
                        -1,
                        withExtraLineBreak
                    );
                    check(corrected.inserted());
                    check(corrected.expectedText().equals(expected));
                    check(corrected.correctionStart() == insertionEnd);
                }
            }
        }
        verifyLongFieldWithUnavailableSelection();
    }

    private static void verifyLongFieldWithUnavailableSelection() {
        String prefix = "a".repeat(10_000);
        String suffix = "b".repeat(10_000);
        String before = prefix + suffix;
        String inserted = "x";
        String expected = prefix + inserted + suffix;

        DictationInsertionResult exact = DictationInsertionResult.evaluate(
            before,
            inserted,
            -1,
            -1,
            expected
        );
        check(exact.inserted());
        check(!exact.needsCorrection());

        int insertionEnd = prefix.length() + inserted.length();
        String withExtraLineBreak = expected.substring(0, insertionEnd)
            + "\n"
            + expected.substring(insertionEnd);
        DictationInsertionResult corrected = DictationInsertionResult.evaluate(
            before,
            inserted,
            -1,
            -1,
            withExtraLineBreak
        );
        check(corrected.inserted());
        check(corrected.needsCorrection());
        check(corrected.expectedText().equals(expected));
        check(corrected.correctionStart() == insertionEnd);
    }

    private static void check(boolean condition) {
        if (!condition) throw new AssertionError("Dictation insertion invariant failed");
    }
}
