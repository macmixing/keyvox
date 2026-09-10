package org.keyvox.android.ime;

/** Installed JNI/Swift composition checks against a stateful InputConnection fixture. */
final class CompositionInstrumentationChecks {
    private static String stage;
    private static final StringBuilder timings = new StringBuilder();

    private CompositionInstrumentationChecks() {}

    static String run() {
        timings.setLength(0);
        measure("empty", CompositionInstrumentationChecks::verifyEmptyField);
        measure("surrounding", CompositionInstrumentationChecks::verifySurroundingText);
        measure("punctuation", CompositionInstrumentationChecks::verifyPunctuationReplacement);
        measure("selection", CompositionInstrumentationChecks::verifySelectionReplacement);
        measure("context fallback", CompositionInstrumentationChecks::verifyUnavailableAndTruncatedContext);
        measure("unicode/no speech", CompositionInstrumentationChecks::verifyUnicodeAndNoSpeech);
        measure("editor change", CompositionInstrumentationChecks::verifyEditorChangeProtection);
        return timings.toString();
    }

    private static void verifyEmptyField() {
        stage = "empty field";
        EditorBufferConnection fixture = new EditorBufferConnection("", 0, 0);
        EditorConnectionOwner owner = new EditorConnectionOwner();
        long destination = owner.attach(fixture.connection);
        check(owner.commitDictation(destination, 1, "Ready."));
        check(fixture.text().equals("Ready."));
    }

    private static void verifySurroundingText() {
        stage = "surrounding text";
        EditorBufferConnection fixture = new EditorBufferConnection("leftright", 4, 4);
        EditorConnectionOwner owner = new EditorConnectionOwner();
        long destination = owner.attach(fixture.connection);
        check(owner.commitDictation(destination, 2, "Middle"));
        check(fixture.text().equals("left middle right"));
    }

    private static void verifyPunctuationReplacement() {
        stage = "punctuation replacement";
        EditorBufferConnection fixture = new EditorBufferConnection("left.right", 4, 4);
        EditorConnectionOwner owner = new EditorConnectionOwner();
        long destination = owner.attach(fixture.connection);
        check(owner.commitDictation(destination, 3, "Question?"));
        check(fixture.text().equals("left question?right"));

        stage = "punctuation UTF-16 fallback";
        EditorBufferConnection fallback = new EditorBufferConnection("left.right", 4, 4);
        fallback.setCodePointDeletionAvailable(false);
        destination = owner.attach(fallback.connection);
        check(owner.commitDictation(destination, 4, "Question?"));
        check(fallback.text().equals("left question?right"));

        stage = "punctuation deletion retry";
        EditorBufferConnection retry = new EditorBufferConnection("left.right", 4, 4);
        retry.setCodePointDeletionAvailable(false);
        retry.setUtf16DeletionAvailable(false);
        destination = owner.attach(retry.connection);
        check(!owner.commitDictation(destination, 5, "Question?"));
        check(retry.text().equals("left question?.right"));
        retry.setUtf16DeletionAvailable(true);
        check(owner.retryPendingDictationDeletion(destination, 5));
        check(retry.text().equals("left question?right"));

        stage = "punctuation retry moved caret";
        EditorBufferConnection moved = new EditorBufferConnection("left.right", 4, 4);
        moved.setCodePointDeletionAvailable(false);
        moved.setUtf16DeletionAvailable(false);
        destination = owner.attach(moved.connection);
        check(!owner.commitDictation(destination, 6, "Question?"));
        String partiallyApplied = moved.text();
        moved.setSelection(0, 0);
        check(owner.retryPendingDictationDeletion(destination, 6));
        check(moved.text().equals(partiallyApplied));

        stage = "punctuation retry editor change";
        EditorBufferConnection original = new EditorBufferConnection("left.right", 4, 4);
        original.setCodePointDeletionAvailable(false);
        original.setUtf16DeletionAvailable(false);
        destination = owner.attach(original.connection);
        check(!owner.commitDictation(destination, 7, "Question?"));
        check(original.text().equals("left question?.right"));
        EditorBufferConnection replacement = new EditorBufferConnection("second", 6, 6);
        owner.attach(replacement.connection);
        check(owner.retryPendingDictationDeletion(destination, 7));
        check(original.text().equals("left question?.right"));
        check(replacement.text().equals("second"));
    }

    private static void verifySelectionReplacement() {
        stage = "selection replacement";
        EditorBufferConnection fixture = new EditorBufferConnection("left middle right", 5, 11);
        EditorConnectionOwner owner = new EditorConnectionOwner();
        long destination = owner.attach(fixture.connection);
        check(owner.commitDictation(destination, 8, "Replacement."));
        check(fixture.text().equals("left replacement right"));
    }

    private static void verifyUnavailableAndTruncatedContext() {
        stage = "unavailable context";
        EditorBufferConnection unavailable = new EditorBufferConnection("selected", 0, 8);
        unavailable.setSurroundingTextAvailable(false);
        EditorConnectionOwner owner = new EditorConnectionOwner();
        long destination = owner.attach(unavailable.connection);
        check(owner.commitDictation(destination, 8, "Unchanged."));
        check(unavailable.text().equals("Unchanged."));

        String exactLimit = " ".repeat(2048);
        stage = "complete context at retained limit";
        EditorBufferConnection complete = new EditorBufferConnection(
            exactLimit, exactLimit.length(), exactLimit.length());
        destination = owner.attach(complete.connection);
        check(owner.commitDictation(destination, 9, "Continuation."));
        check(complete.text().equals(exactLimit + "Continuation."));

        String preceding = " ".repeat(2049);
        stage = "truncated context";
        EditorBufferConnection truncated = new EditorBufferConnection(preceding, preceding.length(), preceding.length());
        destination = owner.attach(truncated.connection);
        check(owner.commitDictation(destination, 10, "Continuation."));
        check(truncated.text().equals(preceding + "continuation."));

        stage = "editor-capped context";
        EditorBufferConnection capped = new EditorBufferConnection(
            preceding, preceding.length(), preceding.length());
        capped.setSurroundingTextCap(1024);
        destination = owner.attach(capped.connection);
        check(owner.commitDictation(destination, 11, "Continuation."));
        check(capped.text().equals(preceding + "continuation."));

        stage = "editor-capped context without selection metadata";
        EditorBufferConnection cappedWithoutSelection = new EditorBufferConnection(
            preceding, preceding.length(), preceding.length());
        cappedWithoutSelection.setSurroundingTextCap(1024);
        cappedWithoutSelection.setExtractedTextAvailable(false);
        destination = owner.attach(cappedWithoutSelection.connection);
        check(owner.commitDictation(destination, 12, "Continuation."));
        check(cappedWithoutSelection.text().equals(preceding + "continuation."));
    }

    private static void verifyUnicodeAndNoSpeech() {
        stage = "unicode insertion";
        EditorBufferConnection fixture = new EditorBufferConnection("🙂tail", 2, 2);
        EditorConnectionOwner owner = new EditorConnectionOwner();
        long destination = owner.attach(fixture.connection);
        check(owner.commitDictation(destination, 13, "Next?"));
        check(fixture.text().equals("🙂 Next? tail"));

        EditorBufferConnection selection = new EditorBufferConnection("🙂", 0, 2);
        stage = "no speech selection";
        destination = owner.attach(selection.connection);
        check(owner.commitDictation(destination, 14, ""));
        check(selection.text().equals("🙂"));
    }

    private static void verifyEditorChangeProtection() {
        stage = "editor change";
        EditorBufferConnection first = new EditorBufferConnection("first", 5, 5);
        EditorBufferConnection second = new EditorBufferConnection("second", 6, 6);
        EditorConnectionOwner owner = new EditorConnectionOwner();
        long staleDestination = owner.attach(first.connection);
        owner.attach(second.connection);
        check(!owner.commitDictation(staleDestination, 15, "Late."));
        check(first.text().equals("first"));
        check(second.text().equals("second"));
    }

    private static void check(boolean condition) {
        if (!condition) throw new AssertionError("Composition integration invariant failed: " + stage);
    }

    private static void measure(String label, Runnable check) {
        long started = android.os.SystemClock.elapsedRealtimeNanos();
        check.run();
        long milliseconds = (android.os.SystemClock.elapsedRealtimeNanos() - started) / 1_000_000;
        timings.append(label).append('=').append(milliseconds).append("ms ");
    }
}
