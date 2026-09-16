package org.keyvox.android.dictation;

/** Describes the verified text change produced by one dictation insertion. */
public final class DictationInsertionResult {
    private static final int NO_CORRECTION = -1;

    private final boolean inserted;
    private final String expectedText;
    private final int correctionStart;

    private DictationInsertionResult(
            boolean inserted,
            String expectedText,
            int correctionStart) {
        this.inserted = inserted;
        this.expectedText = expectedText;
        this.correctionStart = correctionStart;
    }

    public static DictationInsertionResult evaluate(
            String before,
            String insertedText,
            int selectionStart,
            int selectionEnd,
            String after) {
        if (insertedText.isEmpty() || after.equals(before)) return failed();

        if (validSelection(before, selectionStart, selectionEnd)) {
            return evaluateAt(before, insertedText, selectionStart, selectionEnd, after);
        }

        DictationInsertionResult correction = null;
        int lowestCursor = before.length() - commonSuffixLength(before, after);
        int highestCursor = commonPrefixLength(before, after);
        for (int cursor = lowestCursor; cursor <= highestCursor; cursor++) {
            DictationInsertionResult candidate = evaluateAt(
                before,
                insertedText,
                cursor,
                cursor,
                after
            );
            if (candidate.inserted && !candidate.needsCorrection()) return candidate;
            if (candidate.needsCorrection()) {
                if (correction != null
                        && correction.correctionStart != candidate.correctionStart) {
                    return insertedWithoutCorrection();
                }
                correction = candidate;
            }
        }

        if (correction != null) return correction;
        return after.contains(insertedText) ? insertedWithoutCorrection() : failed();
    }

    public boolean inserted() {
        return inserted;
    }

    public boolean needsCorrection() {
        return correctionStart != NO_CORRECTION;
    }

    public String expectedText() {
        return expectedText;
    }

    public int correctionStart() {
        return correctionStart;
    }

    private static DictationInsertionResult evaluateAt(
            String before,
            String insertedText,
            int start,
            int end,
            String after) {
        String expected = before.substring(0, start)
            + insertedText
            + before.substring(end);
        if (after.equals(expected)) {
            return new DictationInsertionResult(true, expected, NO_CORRECTION);
        }

        int insertionEnd = start + insertedText.length();
        if (after.length() == expected.length() + 1
                && after.charAt(insertionEnd) == '\n'
                && after.substring(0, insertionEnd).equals(expected.substring(0, insertionEnd))
                && after.substring(insertionEnd + 1).equals(expected.substring(insertionEnd))) {
            return new DictationInsertionResult(true, expected, insertionEnd);
        }
        return failed();
    }

    private static boolean validSelection(String text, int start, int end) {
        return start >= 0 && start <= end && end <= text.length();
    }

    private static int commonPrefixLength(String left, String right) {
        int limit = Math.min(left.length(), right.length());
        int index = 0;
        while (index < limit && left.charAt(index) == right.charAt(index)) index++;
        return index;
    }

    private static int commonSuffixLength(String left, String right) {
        int limit = Math.min(left.length(), right.length());
        int index = 0;
        while (index < limit
                && left.charAt(left.length() - 1 - index)
                    == right.charAt(right.length() - 1 - index)) {
            index++;
        }
        return index;
    }

    private static DictationInsertionResult insertedWithoutCorrection() {
        return new DictationInsertionResult(true, null, NO_CORRECTION);
    }

    private static DictationInsertionResult failed() {
        return new DictationInsertionResult(false, null, NO_CORRECTION);
    }
}
